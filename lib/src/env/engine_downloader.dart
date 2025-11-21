import 'dart:io';

import 'package:process/process.dart';

import '../command_result.dart';
import '../config/config.dart';
import '../downloader.dart';
import '../http.dart';
import '../install/profile.dart';
import '../logger.dart';
import '../process.dart';
import '../progress.dart';
import '../provider.dart';
import '../terminal.dart';
import 'engine_enums.dart';
import 'engine_platform_detector.dart';
import 'gc.dart';

/// Handles downloading and unzipping of Flutter engines.
class EngineDownloader {
  const EngineDownloader();

  /// Downloads a shared engine if not already present.
  Future<bool> downloadSharedEngine({
    required Scope scope,
    required String engineCommit,
  }) async {
    final config = HavenConfig.of(scope);
    final log = HVLogger.of(scope);
    final sharedCache = config.getFlutterCache(engineCommit, patched: false);
    var didDownloadEngine = false;

    // Delete the current cache if it's corrupt
    if (sharedCache.exists) {
      try {
        await ProgressNode.of(scope).wrap((scope, node) async {
          node.description = 'Checking if dart works';
          await runProcess(
            scope,
            sharedCache.dartSdk.dartExecutable.path,
            ['--version'],
            throwOnFailure: true,
            environment: {'PUB_CACHE': config.legacyPubCacheDir.path},
          );
        });
      } catch (exception) {
        log.w('dart version check failed, deleting cache');
        sharedCache.cacheDir.deleteSync(recursive: true);
      }
    }

    if (!sharedCache.exists) {
      log.v('Downloading engine');

      const detector = EnginePlatformDetector();
      final target = await detector.queryBuildTarget(scope: scope);
      final engineZipUrl = config.flutterStorageBaseUrl.append(
        path: 'flutter_infra_release/flutter/$engineCommit/${target.zipName}',
      );
      sharedCache.cacheDir.createSync(recursive: true);
      final zipFile = config.sharedCachesDir.childFile('$engineCommit.zip');
      try {
        await downloadFile(
          scope: scope,
          url: engineZipUrl,
          file: zipFile,
          description: 'Downloading engine',
        );
      } on HttpException catch (e) {
        // Flutter versions older than 3.0.0 don't have builds for M1 chips but
        // the intel ones will run fine, in the future we could check the contents
        // of shared.sh or the git tree, but this is much simpler.
        if (e.statusCode == 404 && target == EngineBuildTarget.macosArm64) {
          final engineZipUrl = config.flutterStorageBaseUrl.append(
            path:
                'flutter_infra_release/flutter/$engineCommit/'
                '${EngineBuildTarget.macosX64.zipName}',
          );
          await downloadFile(
            scope: scope,
            url: engineZipUrl,
            file: zipFile,
            description: 'Downloading engine',
          );
        } else {
          rethrow;
        }
      }

      log.v('Unzipping into ${config.sharedCachesDir}');
      await ProgressNode.of(scope).wrap((scope, node) async {
        node.description = 'Unzipping engine';
        await unzip(scope: scope, zipFile: zipFile, destination: sharedCache.cacheDir);
      });

      zipFile.deleteSync();

      didDownloadEngine = true;
    }

    if (didDownloadEngine) {
      await runOptional(scope, 'Collecting garbage', () async {
        await collectGarbage(scope: scope);
      });
    }

    return didDownloadEngine;
  }

  /// Unzips a zip file into a destination directory.
  Future<void> unzip({
    required Scope scope,
    required File zipFile,
    required Directory destination,
  }) async {
    destination.createSync(recursive: true);
    if (Platform.isWindows) {
      final zip = await findProgramInPath(scope: scope, name: '7z');
      if (zip.isNotEmpty) {
        await runProcess(scope, zip.first.path, [
          'x',
          '-y',
          '-o${destination.path}',
          zipFile.path,
        ], throwOnFailure: true);
      } else {
        await runProcess(scope, 'powershell', [
          'Import-Module Microsoft.PowerShell.Archive; Expand-Archive',
          zipFile.path,
          '-DestinationPath',
          destination.path,
        ], throwOnFailure: true);
      }
    } else if (Platform.isLinux || Platform.isMacOS) {
      const pm = LocalProcessManager();
      if (!pm.canRun('unzip')) {
        throw CommandError.list([
          CommandMessage('unzip not found in your PATH'),
          CommandMessage(
            Platform.isLinux
                ? 'Try running `sudo apt install unzip`'
                : 'Try running `brew install unzip`',
            type: CompletionType.info,
          ),
        ]);
      }
      await runProcess(
        scope,
        'unzip',
        ['-o', '-q', zipFile.path, '-d', destination.path],
        runInShell: true,
        throwOnFailure: true,
      );
    } else {
      throw UnsupportedOSError();
    }
  }
}
