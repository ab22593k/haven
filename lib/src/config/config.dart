import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file/file.dart';

import '../../models.dart';
import '../command_line_args_config.dart';
import '../command_result.dart';
import '../config/core.dart';
import '../config/prefs.dart';
import '../env/dart.dart';
import '../extensions.dart';
import '../file_lock.dart';
import '../provider.dart';
import '../version.dart';
import 'config_creation.dart';
import 'config_utils.dart';
import 'project.dart';

export 'config_creation.dart';
export 'config_utils.dart';

const prettyJsonEncoder = JsonEncoder.withIndent('  ');

class HavenConfig {
  HavenConfig({
    required this.core,
    required this.globalPrefs,
    required this.project,
    required this.legacyPubCacheDir,
    required this.legacyPubCache,
    required this.environmentOverride,
    required this.shouldInstall,
    required this.shouldSkipCacheSync,
  });

  final CoreConfig core;
  final GlobalPrefsConfig globalPrefs;
  final ProjectConfig project;
  final Directory legacyPubCacheDir;
  final bool legacyPubCache;
  final String? environmentOverride;
  final bool shouldInstall;
  final bool shouldSkipCacheSync;

  File get globalPrefsJsonFile => globalPrefs.jsonFile;

  FileSystem get fileSystem => core.fileSystem;
  File get gitExecutable => core.gitExecutable;
  Directory get havenRoot => core.havenRoot;
  Directory get homeDir => core.homeDir;
  Directory? get projectDir => project.projectDir;
  Directory? get parentProjectDir => project.parentProjectDir;

  String get flutterGitUrl =>
      globalPrefs.flutterGitUrl ?? 'https://github.com/flutter/flutter.git';
  String get engineGitUrl =>
      globalPrefs.engineGitUrl ?? 'https://github.com/flutter/engine.git';
  String get dartSdkGitUrl =>
      globalPrefs.dartSdkGitUrl ?? 'https://github.com/dart-lang/sdk.git';
  Uri get releasesJsonUrl => Uri.parse(globalPrefs.releasesJsonUrl ??
      '$flutterStorageBaseUrl/flutter_infra_release/releases/releases_${Platform.operatingSystem}.json');
  Uri get flutterStorageBaseUrl =>
      Uri.parse(globalPrefs.flutterStorageBaseUrl ?? 'https://storage.googleapis.com');
  Uri get havenBuildsUrl =>
      Uri.parse(globalPrefs.havenBuildsUrl ?? 'https://puro.dev/builds');
  HavenBuildTarget get buildTarget => globalPrefs.havenBuildTarget != null
      ? HavenBuildTarget.fromString(globalPrefs.havenBuildTarget!)
      : HavenBuildTarget.query();
  bool get enableShims => core.enableShims;

  static Future<HavenConfig> fromCommandLine({
    required Scope scope,
    required FileSystem fileSystem,
    required String? gitExecutable,
    required Directory havenRoot,
    required Directory homeDir,
    required String? workingDir,
    required String? projectDir,
    required String? pubCache,
    required bool? legacyPubCache,
    required String? flutterGitUrl,
    required String? engineGitUrl,
    required String? dartSdkGitUrl,
    required String? releasesJsonUrl,
    required String? flutterStorageBaseUrl,
    required String? environmentOverride,
    required bool? shouldInstall,
    required bool? shouldSkipCacheSync,
    required bool firstRun,
    // Global shims break IDE auto-detection, we use symlinks now instead
    bool enableShims = false,
  }) async {
    final args = CommandLineArgsConfig(
      gitExecutable: gitExecutable,
      workingDir: workingDir,
      projectDir: projectDir,
      pubCache: pubCache,
      legacyPubCache: legacyPubCache,
      flutterGitUrl: flutterGitUrl,
      engineGitUrl: engineGitUrl,
      dartSdkGitUrl: dartSdkGitUrl,
      releasesJsonUrl: releasesJsonUrl,
      flutterStorageBaseUrl: flutterStorageBaseUrl,
      environmentOverride: environmentOverride,
      shouldInstall: shouldInstall,
      shouldSkipCacheSync: shouldSkipCacheSync,
    );
    return createHavenConfig(
        scope: scope,
        fileSystem: fileSystem,
        havenRoot: havenRoot,
        homeDir: homeDir,
        args: args,
        firstRun: firstRun,
        enableShims: enableShims);
  }

  static Directory getHomeDir({
    required Scope scope,
    required FileSystem fileSystem,
  }) {
    return CoreConfig.getHomeDir(fileSystem: fileSystem);
  }

  static Directory getHavenRoot({
    required Scope scope,
    required FileSystem fileSystem,
    required Directory homeDir,
  }) {
    return CoreConfig.getHavenRoot(fileSystem: fileSystem, homeDir: homeDir);
  }

  Directory get envsDir => core.envsDir;
  Directory get binDir => core.binDir;
  Directory get sharedDir => core.sharedDir;
  Directory get sharedFlutterDir => core.sharedFlutterDir;
  Directory get sharedEngineDir => core.sharedEngineDir;
  Directory get sharedDartSdkDir => core.sharedDartSdkDir;
  Directory get sharedDartReleaseDir => core.sharedDartReleaseDir;
  Directory get sharedCachesDir => core.sharedCachesDir;
  Directory get sharedGClientDir => core.sharedGClientDir;
  Directory get pubCacheBinDir => legacyPubCacheDir.childDirectory('bin');
  Directory get sharedFlutterToolsDir => core.sharedFlutterToolsDir;
  File get havenExecutableFile => core.havenExecutableFile;
  File get havenTrampolineFile => core.havenTrampolineFile;
  File get havenDartShimFile => core.havenDartShimFile;
  File get havenFlutterShimFile => core.havenFlutterShimFile;
  File get havenExecutableTempFile => core.havenExecutableTempFile;
  File get cachedReleasesJsonFile => core.cachedReleasesJsonFile;
  File get cachedDartReleasesJsonFile => core.cachedDartReleasesJsonFile;
  File get defaultEnvNameFile => core.defaultEnvNameFile;
  Link get defaultEnvLink => core.defaultEnvLink;
  Uri get havenLatestVersionUrl => core.havenLatestVersionUrl;
  File get havenLatestVersionFile => core.havenLatestVersionFile;
  Directory get depotToolsDir => core.depotToolsDir;

  List<String> get desiredEnvPaths => [
        binDir.path,
        pubCacheBinDir.path,
        getEnv('default', resolve: false).flutter.binDir.path,
      ];

  EnvConfig getEnv(String name, {bool resolve = true}) {
    if (resolve && name == 'default') {
      if (defaultEnvLink.existsSync()) {
        final target = fileSystem.directory(defaultEnvLink.targetSync());
        name = target.basename;
      } else {
        name = 'stable';
      }
    }
    name = name.toLowerCase();
    ensureValidEnvName(name);
    return EnvConfig(parentConfig: this, envDir: envsDir.childDirectory(name));
  }

  EnvConfig? tryGetProjectEnv() {
    if (environmentOverride != null) {
      final result = getEnv(environmentOverride!);
      return result.exists ? result : null;
    }
    return project.tryGetProjectEnv();
  }

  Directory? findVSCodeWorkspaceDir(Directory projectDir) {
    final dir = findProjectDir(projectDir, '.vscode');
    if (dir != null && dir.pathEquals(homeDir)) {
      return null;
    }
    return dir;
  }

  FlutterCacheConfig getFlutterCache(
    String engineCommit, {
    required bool patched,
  }) {
    if (!isValidCommitHash(engineCommit)) {
      throw ArgumentError.value(
        engineCommit,
        'engineVersion',
        'Invalid commit hash',
      );
    }
    if (patched) {
      return FlutterCacheConfig(sharedCachesDir.childDirectory(
        '${engineCommit}_patched',
      ));
    } else {
      return FlutterCacheConfig(sharedCachesDir.childDirectory(engineCommit));
    }
  }

  DartSdkConfig getDartRelease(DartRelease release) {
    return DartSdkConfig(
        sharedDartReleaseDir.childDirectory(release.name).childDirectory('dart-sdk'));
  }

  Uri? tryGetFlutterGitDownloadUrl({
    required String commit,
    required String path,
  }) {
    const httpPrefix = 'https://github.com/';
    const sshPrefix = 'git@github.com:';
    final isHttp = flutterGitUrl.startsWith(httpPrefix);
    if ((isHttp || flutterGitUrl.startsWith(sshPrefix)) &&
        flutterGitUrl.endsWith('.git')) {
      return Uri.https(
        'raw.githubusercontent.com',
        '${flutterGitUrl.substring(
          isHttp ? httpPrefix.length : sshPrefix.length,
          flutterGitUrl.length - 4,
        )}/$commit/$path',
      );
    }
    return null;
  }

  Uri? tryGetEngineGitDownloadUrl({
    required String commit,
    required String path,
  }) {
    const httpPrefix = 'https://github.com/';
    const sshPrefix = 'git@github.com:';
    final isHttp = engineGitUrl.startsWith(httpPrefix);
    if ((isHttp || engineGitUrl.startsWith(sshPrefix)) &&
        engineGitUrl.endsWith('.git')) {
      return Uri.https(
        'raw.githubusercontent.com',
        '${engineGitUrl.substring(
          isHttp ? httpPrefix.length : sshPrefix.length,
          engineGitUrl.length - 4,
        )}/$commit/$path',
      );
    }
    return null;
  }

  String shortenHome(String path) {
    if (path.startsWith(homeDir.path)) {
      return '~' + path.substring(homeDir.path.length);
    }
    return path;
  }

  @override
  String toString() {
    return 'HavenConfig(\n'
        '  core: $core,\n'
        '  globalPrefs: $globalPrefs,\n'
        '  project: $project,\n'
        '  legacyPubCacheDir: $legacyPubCacheDir,\n'
        '  legacyPubCache: $legacyPubCache,\n'
        '  environmentOverride: $environmentOverride,\n'
        '  shouldInstall: $shouldInstall,\n'
        '  shouldSkipCacheSync: $shouldSkipCacheSync,\n'
        '  globalPrefsJsonFile: $globalPrefsJsonFile,\n'
        ')';
  }

  static final provider = Provider<HavenConfig>.late();
  static HavenConfig of(Scope scope) => scope.read(provider);
}

class EnvConfig {
  EnvConfig({
    required this.parentConfig,
    required this.envDir,
  });

  final HavenConfig parentConfig;
  final Directory envDir;

  late final String name = envDir.basename;
  late final Directory recipeDir = envDir.childDirectory('recipe');
  late final Directory engineRootDir = envDir.childDirectory('engine');
  late final EngineConfig engine = EngineConfig(engineRootDir);
  late final Directory flutterDir = envDir.childDirectory('flutter');
  late final FlutterConfig flutter = FlutterConfig(flutterDir);
  late final File prefsJsonFile = envDir.childFile('prefs.json');
  late final File updateLockFile = envDir.childFile('update.lock');
  late final Directory evalDir = envDir.childDirectory('eval');
  late final Directory evalBootstrapDir = evalDir.childDirectory('bootstrap');
  late final File evalBootstrapPackagesFile =
      evalBootstrapDir.childDirectory('.dart_tool').childFile('package_config.json');

  bool get exists => envDir.existsSync();

  void ensureExists([String? message]) {
    if (!exists) {
      throw CommandError(message ?? 'Environment `$name` does not exist');
    }
  }

  // TODO(ping): Maybe support changing this in the future, the flutter tool
  // lets you change it with an environment variable
  String get flutterToolArgs => '';

  Future<HavenEnvPrefsModel> readPrefs({
    required Scope scope,
  }) async {
    final model = HavenEnvPrefsModel();
    if (prefsJsonFile.existsSync()) {
      final contents = await readAtomic(scope: scope, file: prefsJsonFile);
      final parsed = jsonDecode(contents) as Map<String, dynamic>;
      validateJsonAgainstProto3Schema(parsed, HavenEnvPrefsModel.create);
      model.mergeFromProto3Json(parsed);
    }
    return model;
  }

  Future<HavenEnvPrefsModel> updatePrefs({
    required Scope scope,
    required FutureOr<void> Function(HavenEnvPrefsModel prefs) fn,
    bool background = false,
  }) {
    return lockFile(
      scope,
      prefsJsonFile,
      (handle) async {
        final model = HavenEnvPrefsModel();
        String? contents;
        if (handle.lengthSync() > 0) {
          contents = handle.readAllAsStringSync();
          final parsed = jsonDecode(contents) as Map<String, dynamic>;
          validateJsonAgainstProto3Schema(parsed, HavenEnvPrefsModel.create);
          model.mergeFromProto3Json(parsed);
        }
        await fn(model);
        final newContents = prettyJsonEncoder.convert(model.toProto3Json());
        if (contents != newContents) {
          handle.writeAllStringSync(newContents);
        }
        return model;
      },
      mode: FileMode.append,
    );
  }
}

class FlutterConfig {
  FlutterConfig(this.sdkDir);

  final Directory sdkDir;

  late final Directory binDir = sdkDir.childDirectory('bin');
  late final Directory packagesDir = sdkDir.childDirectory('packages');
  late final File flutterScript =
      binDir.childFile(Platform.isWindows ? 'flutter.bat' : 'flutter');
  late final File dartScript =
      binDir.childFile(Platform.isWindows ? 'dart.bat' : 'dart');
  late final Directory binInternalDir = binDir.childDirectory('internal');
  late final Directory cacheDir = binDir.childDirectory('cache');
  late final FlutterCacheConfig cache = FlutterCacheConfig(cacheDir);
  late final File engineVersionFile = binInternalDir.childFile('engine.version');
  late final Directory flutterToolsDir = packagesDir.childDirectory('flutter_tools');
  late final File flutterToolsScriptFile =
      flutterToolsDir.childDirectory('bin').childFile('flutter_tools.dart');
  late final File flutterToolsPubspecYamlFile =
      flutterToolsDir.childFile('pubspec.yaml');
  late final File flutterToolsPubspecLockFile =
      flutterToolsDir.childFile('pubspec.lock');
  late final File flutterToolsPackageConfigJsonFile =
      flutterToolsDir.childDirectory('.dart_tool').childFile('package_config.json');
  late final File flutterToolsLegacyPackagesFile =
      flutterToolsDir.childFile('.packages');
  late final File legacyVersionFile = sdkDir.childFile('version');

  String? get engineVersion => engineVersionFile.existsSync()
      ? engineVersionFile.readAsStringSync().trim()
      : null;

  bool get hasEngine => sdkDir
      .childDirectory('engine')
      .childDirectory('src')
      .childFile('.gn')
      .existsSync();
}

class FlutterCacheConfig {
  FlutterCacheConfig(this.cacheDir);

  final Directory cacheDir;

  late final Directory dartSdkDir = cacheDir.childDirectory('dart-sdk');
  late final DartSdkConfig dartSdk = DartSdkConfig(dartSdkDir);

  late final File flutterToolsStampFile = cacheDir.childFile('flutter_tools.stamp');
  late final File engineStampFile = cacheDir.childFile('engine.stamp');
  late final File engineRealmFile = cacheDir.childFile('engine.realm');
  late final File engineVersionFile = cacheDir.childFile('engine-dart-sdk.stamp');
  String? get engineVersion => engineVersionFile.existsSync()
      ? engineVersionFile.readAsStringSync().trim()
      : null;
  String? get flutterToolsStamp => flutterToolsStampFile.existsSync()
      ? flutterToolsStampFile.readAsStringSync().trim()
      : null;
  late final File versionJsonFile = cacheDir.childFile('flutter.version.json');

  bool get exists => cacheDir.existsSync();
}

class DartSdkConfig {
  DartSdkConfig(this.sdkDir);

  final Directory sdkDir;

  late final Directory binDir = sdkDir.childDirectory('bin');

  late final File dartExecutable =
      binDir.childFile(Platform.isWindows ? 'dart.exe' : 'dart');

  // This no longer exists on recent versions of Dart where we instead use
  // `dart pub`.
  late final File oldPubExecutable =
      binDir.childFile(Platform.isWindows ? 'pub.bat' : 'pub');

  late final Directory libDir = sdkDir.childDirectory('lib');
  late final Directory internalLibDir = libDir.childDirectory('_internal');
  late final File librariesJsonFile = libDir.childFile('libraries.json');
  late final File internalLibrariesDartFile = internalLibDir
      .childDirectory('sdk_library_metadata')
      .childDirectory('lib')
      .childFile('libraries.dart');
  late final File revisionFile = sdkDir.childFile('revision');
  late final File versionFile = sdkDir.childFile('version');
  late final File versionJsonFile = sdkDir.childFile('version.json');
  late final commitHash = revisionFile.readAsStringSync().trim();
}

class EngineConfig {
  EngineConfig(this.rootDir);

  final Directory rootDir;

  late final File gclientFile = rootDir.childFile('.gclient');
  late final Directory srcDir = rootDir.childDirectory('src');
  late final Directory engineSrcDir = srcDir.childDirectory('flutter');

  bool get exists => rootDir.existsSync();

  void ensureExists([String? message]) {
    if (!exists) {
      throw CommandError(
        message ??
            'Environment `${rootDir.parent.basename}` does not have a custom engine, '
                'use `haven engine prepare ${rootDir.parent.basename}` to create one',
      );
    }
  }
}
