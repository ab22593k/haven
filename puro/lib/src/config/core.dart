import 'dart:io';

import 'package:file/file.dart';

import '../version.dart';

class CoreConfig {
  CoreConfig({
    required this.fileSystem,
    required this.gitExecutable,
    required this.puroRoot,
    required this.homeDir,
    required this.flutterGitUrl,
    required this.engineGitUrl,
    required this.dartSdkGitUrl,
    required this.releasesJsonUrl,
    required this.flutterStorageBaseUrl,
    required this.puroBuildsUrl,
    required this.buildTarget,
    required this.enableShims,
  });

  final FileSystem fileSystem;
  final File gitExecutable;
  final Directory puroRoot;
  final Directory homeDir;
  final String flutterGitUrl;
  final String engineGitUrl;
  final String dartSdkGitUrl;
  final Uri releasesJsonUrl;
  final Uri flutterStorageBaseUrl;
  final Uri puroBuildsUrl;
  final PuroBuildTarget buildTarget;
  final bool enableShims;

  late final Directory envsDir = puroRoot.childDirectory('envs');
  late final Directory binDir = puroRoot.childDirectory('bin');
  late final Directory sharedDir = puroRoot.childDirectory('shared');
  late final Directory sharedFlutterDir = sharedDir.childDirectory('flutter');
  late final Directory sharedEngineDir = sharedDir.childDirectory('engine');
  late final Directory sharedDartSdkDir = sharedDir.childDirectory('dart-sdk');
  late final Directory sharedDartReleaseDir = sharedDir.childDirectory('dart-release');
  late final Directory sharedCachesDir = sharedDir.childDirectory('caches');
  late final Directory sharedGClientDir = sharedDir.childDirectory('gclient');
  late final Directory sharedFlutterToolsDir =
      sharedDir.childDirectory('flutter_tools');
  late final File puroExecutableFile = binDir.childFile(buildTarget.executableName);
  late final File puroTrampolineFile = binDir.childFile(buildTarget.trampolineName);
  late final File puroDartShimFile = binDir.childFile(buildTarget.dartName);
  late final File puroFlutterShimFile = binDir.childFile(buildTarget.flutterName);
  late final File puroExecutableTempFile =
      binDir.childFile('${buildTarget.executableName}.tmp');
  late final File cachedReleasesJsonFile =
      puroRoot.childFile(releasesJsonUrl.pathSegments.last);
  late final File cachedDartReleasesJsonFile = puroRoot.childFile('dart_releases.json');
  late final File defaultEnvNameFile = puroRoot.childFile('default_env');
  late final Link defaultEnvLink = envsDir.childLink('default');
  late final Uri puroLatestVersionUrl =
      puroBuildsUrl.replace(path: puroBuildsUrl.path + '/latest');
  late final File puroLatestVersionFile = puroRoot.childFile('latest_version');
  late final Directory depotToolsDir = puroRoot.childDirectory('depot_tools');

  static Directory getHomeDir({
    required FileSystem fileSystem,
  }) {
    final String homeDir;
    if (Platform.isWindows) {
      homeDir = Platform.environment['UserProfile']!;
    } else {
      homeDir = Platform.environment['HOME']!;
    }
    return fileSystem.directory(homeDir);
  }

  static Directory getPuroRoot({
    required FileSystem fileSystem,
    required Directory homeDir,
  }) {
    final envPuroRoot = Platform.environment['PURO_ROOT'];

    final Directory? binPuroRoot = () {
      final flutterBin = Platform.environment['PURO_FLUTTER_BIN'];
      if (flutterBin == null) {
        return null;
      }
      final flutterBinDir = fileSystem.directory(flutterBin).absolute;
      final flutterSdkDir = flutterBinDir.parent;
      final envDir = flutterSdkDir.parent;
      final envsDir = envDir.parent;
      return envsDir.parent;
    }();

    if (binPuroRoot != null) {
      return binPuroRoot;
    }
    if (envPuroRoot?.isNotEmpty ?? false) {
      return fileSystem.directory(envPuroRoot);
    }
    return homeDir.childDirectory('.puro');
  }

  String shortenHome(String path) {
    if (path.startsWith(homeDir.path)) {
      return '~' + path.substring(homeDir.path.length);
    }
    return path;
  }
}
