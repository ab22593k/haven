import 'package:file/file.dart';

import '../../models.dart';
import '../config/config.dart';
import '../file_lock.dart';
import '../logger.dart';
import '../provider.dart';
import 'create.dart';

extension EnvPrefsModelExtension on HavenEnvPrefsModel {
  bool get isPatched => hasPatched() && patched;
}

/// Manages Flutter cache synchronization between environments and shared cache.
class EngineCacheManager {
  const EngineCacheManager();

  /// Syncs an environment's flutter cache with the shared cache by creating
  /// symlinks to individual files / folders.
  Future<void> syncFlutterCache({
    required Scope scope,
    required EnvConfig environment,
    HavenEnvPrefsModel? environmentPrefs,
  }) async {
    final log = HVLogger.of(scope);
    final config = HavenConfig.of(scope);
    final fs = config.fileSystem;
    final engineVersion = await getEngineVersion(
      scope: scope,
      flutterConfig: environment.flutter,
    );
    if (engineVersion == null) {
      return;
    }
    environmentPrefs ??= await environment.readPrefs(scope: scope);
    final sharedCacheDir = config
        .getFlutterCache(engineVersion, patched: environmentPrefs.isPatched)
        .cacheDir;
    if (!sharedCacheDir.existsSync()) {
      return;
    }
    final cacheDir = environment.flutter.cacheDir;

    if (fs.isLinkSync(cacheDir.path)) {
      // Old versions of haven used to create a symlink to the whole shared cache.
      log.v('Deleting old symlink to shared cache');
      cacheDir.deleteSync();
    }

    if (!cacheDir.existsSync()) {
      cacheDir.createSync(recursive: true);
    }

    // Loop through the files in the cache dir, deleting or moving any that
    // aren't symlinks to the shared cache.
    final cacheDirFiles = <String>{};
    for (final file in cacheDir.listSync()) {
      cacheDirFiles.add(file.basename);
      if (cacheBlacklist.contains(file.basename)) {
        continue;
      }
      final sharedFile = sharedCacheDir.childFile(file.basename);
      if (fs.isLinkSync(file.path)) {
        // Delete the link if it doesn't point to the file we want.
        final link = fs.link(file.path);
        if (link.targetSync() != sharedFile.path) {
          log.d(
            'Deleting ${file.basename} symlink because it points to '
            '`${link.targetSync()}` instead of `${sharedFile.path}`',
          );
          link.deleteSync();
        }
        continue;
      }
      final sharedPath = sharedCacheDir.childFile(file.basename).path;
      if (fs.file(sharedPath).existsSync()) {
        // Delete local copy and link to shared copy, perhaps we could
        // merge them instead?
        log.d(
          'Deleting ${file.basename} because it already exists in the '
          'shared cache',
        );
        file.deleteSync(recursive: true);
      } else {
        // Move it to the shared cache.
        log.d('Moving ${file.basename} to the shared cache');
        file.renameSync(sharedPath);
      }
    }

    final paths = <Link, String>{};

    // Loop through the files in the shared cache, creating symlinks to them
    // in the cache dir.
    for (final file in sharedCacheDir.listSync()) {
      final cachePath = cacheDir.childFile(file.basename).path;
      if (cacheBlacklist.contains(file.basename) || fs.file(cachePath).existsSync()) {
        continue;
      }
      paths[fs.link(cachePath)] = file.path;
      log.d('Creating symlink for ${file.basename}');
    }

    // We create the links all at once to avoid having to elevate multiple times
    // on Windows.
    await createLinks(scope: scope, paths: paths);
  }

  /// Attempts to sync the Flutter cache, handling errors gracefully.
  Future<void> trySyncFlutterCache({
    required Scope scope,
    required EnvConfig environment,
  }) async {
    await runOptional(scope, 'Syncing flutter cache', () async {
      await syncFlutterCache(scope: scope, environment: environment);
    });
  }
}

/// These files shouldn't be shared between flutter installs.
const cacheBlacklist = {'flutter_version_check.stamp', 'flutter.version.json'};
