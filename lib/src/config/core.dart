import 'dart:io';

import 'package:file/file.dart';

import '../version.dart';

class CoreConfig {
  CoreConfig({
    required this.fileSystem,
    required this.gitExecutable,
    required this.havenRoot,
    required this.homeDir,
    required this.flutterGitUrl,
    required this.engineGitUrl,
    required this.dartSdkGitUrl,
    required this.releasesJsonUrl,
    required this.flutterStorageBaseUrl,
    required this.buildTarget,
    required this.enableShims,
  });

  final FileSystem fileSystem;
  final File gitExecutable;
  final Directory havenRoot;
  final Directory homeDir;
  final String flutterGitUrl;
  final String engineGitUrl;
  final String dartSdkGitUrl;
  final Uri releasesJsonUrl;
  final Uri flutterStorageBaseUrl;
  final HavenBuildTarget buildTarget;
  final bool enableShims;

  late final Directory envsDir = havenRoot.childDirectory('envs');
  late final Directory binDir = havenRoot.childDirectory('bin');
  late final Directory sharedDir = havenRoot.childDirectory('shared');
  late final Directory sharedFlutterDir = sharedDir.childDirectory('flutter');
  late final Directory sharedEngineDir = sharedDir.childDirectory('engine');
  late final Directory sharedDartSdkDir = sharedDir.childDirectory('dart-sdk');
  late final Directory sharedDartReleaseDir = sharedDir.childDirectory('dart-release');
  late final Directory sharedCachesDir = sharedDir.childDirectory('caches');
  late final Directory sharedGClientDir = sharedDir.childDirectory('gclient');
  late final Directory sharedFlutterToolsDir = sharedDir.childDirectory(
    'flutter_tools',
  );
  late final File havenExecutableFile = binDir.childFile(buildTarget.executableName);
  late final File havenTrampolineFile = binDir.childFile(buildTarget.trampolineName);
  late final File havenDartShimFile = binDir.childFile(buildTarget.dartName);
  late final File havenFlutterShimFile = binDir.childFile(buildTarget.flutterName);
  late final File havenExecutableTempFile = binDir.childFile(
    '${buildTarget.executableName}.tmp',
  );
  late final File cachedReleasesJsonFile = havenRoot.childFile(
    releasesJsonUrl.pathSegments.last,
  );
  late final File cachedDartReleasesJsonFile = havenRoot.childFile(
    'dart_releases.json',
  );
  late final File defaultEnvNameFile = havenRoot.childFile('default_env');
  late final Link defaultEnvLink = envsDir.childLink('default');
  late final File havenLatestVersionFile = havenRoot.childFile('latest_version');
  late final Directory depotToolsDir = havenRoot.childDirectory('depot_tools');

  static Directory getHomeDir({required FileSystem fileSystem}) {
    final String homeDir;
    if (Platform.isWindows) {
      homeDir = Platform.environment['UserProfile']!;
    } else {
      homeDir = Platform.environment['HOME']!;
    }
    return fileSystem.directory(homeDir);
  }

  static Directory getHavenRoot({
    required FileSystem fileSystem,
    required Directory homeDir,
  }) {
    final envHavenRoot = Platform.environment['HAVEN_ROOT'];

    final Directory? binHavenRoot = () {
      final flutterBin = Platform.environment['HAVEN_FLUTTER_BIN'];
      if (flutterBin == null) {
        return null;
      }
      final flutterBinDir = fileSystem.directory(flutterBin).absolute;
      final flutterSdkDir = flutterBinDir.parent;
      final envDir = flutterSdkDir.parent;
      final envsDir = envDir.parent;
      return envsDir.parent;
    }();

    if (binHavenRoot != null) {
      return binHavenRoot;
    }
    if (envHavenRoot?.isNotEmpty ?? false) {
      return fileSystem.directory(envHavenRoot);
    }
    return homeDir.childDirectory('.haven');
  }

  String shortenHome(String path) {
    if (path.startsWith(homeDir.path)) {
      return '~' + path.substring(homeDir.path.length);
    }
    return path;
  }
}
