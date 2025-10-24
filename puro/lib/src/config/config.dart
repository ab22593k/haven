import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file/file.dart';
import 'package:path/path.dart' as path;
import 'package:process/process.dart';
import 'package:pub_semver/pub_semver.dart';

import '../../models.dart';
import '../command_line_args_config.dart';
import '../command_result.dart';
import '../config/core.dart';
import '../config/prefs.dart';
import '../env/dart.dart';
import '../extensions.dart';
import '../file_lock.dart';
import '../logger.dart';
import '../provider.dart';
import '../version.dart';
import 'project.dart';

const prettyJsonEncoder = JsonEncoder.withIndent('  ');

Directory? findProjectDir(Directory directory, String fileName) {
  while (directory.existsSync()) {
    if (directory.fileSystem.statSync(directory.childFile(fileName).path).type !=
        FileSystemEntityType.notFound) {
      return directory;
    }
    final parent = directory.parent;
    if (directory.path == parent.path) break;
    directory = parent;
  }
  return null;
}

class PuroConfig {
  PuroConfig({
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
  Directory get puroRoot => core.puroRoot;
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
  Uri get puroBuildsUrl =>
      Uri.parse(globalPrefs.puroBuildsUrl ?? 'https://puro.dev/builds');
  PuroBuildTarget get buildTarget => globalPrefs.puroBuildTarget != null
      ? PuroBuildTarget.fromString(globalPrefs.puroBuildTarget!)
      : PuroBuildTarget.query();
  bool get enableShims => core.enableShims;

  static Future<PuroConfig> fromCommandLine({
    required Scope scope,
    required FileSystem fileSystem,
    required String? gitExecutable,
    required Directory puroRoot,
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
    return createPuroConfig(
        scope: scope,
        fileSystem: fileSystem,
        puroRoot: puroRoot,
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

  static Directory getPuroRoot({
    required Scope scope,
    required FileSystem fileSystem,
    required Directory homeDir,
  }) {
    return CoreConfig.getPuroRoot(fileSystem: fileSystem, homeDir: homeDir);
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
  File get puroExecutableFile => core.puroExecutableFile;
  File get puroTrampolineFile => core.puroTrampolineFile;
  File get puroDartShimFile => core.puroDartShimFile;
  File get puroFlutterShimFile => core.puroFlutterShimFile;
  File get puroExecutableTempFile => core.puroExecutableTempFile;
  File get cachedReleasesJsonFile => core.cachedReleasesJsonFile;
  File get cachedDartReleasesJsonFile => core.cachedDartReleasesJsonFile;
  File get defaultEnvNameFile => core.defaultEnvNameFile;
  Link get defaultEnvLink => core.defaultEnvLink;
  Uri get puroLatestVersionUrl => core.puroLatestVersionUrl;
  File get puroLatestVersionFile => core.puroLatestVersionFile;
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
    return 'PuroConfig(\n'
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

  static final provider = Provider<PuroConfig>.late();
  static PuroConfig of(Scope scope) => scope.read(provider);
}

class EnvConfig {
  EnvConfig({
    required this.parentConfig,
    required this.envDir,
  });

  final PuroConfig parentConfig;
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

  Future<PuroEnvPrefsModel> readPrefs({
    required Scope scope,
  }) async {
    final model = PuroEnvPrefsModel();
    if (prefsJsonFile.existsSync()) {
      final contents = await readAtomic(scope: scope, file: prefsJsonFile);
      model.mergeFromProto3Json(jsonDecode(contents));
    }
    return model;
  }

  Future<PuroEnvPrefsModel> updatePrefs({
    required Scope scope,
    required FutureOr<void> Function(PuroEnvPrefsModel prefs) fn,
    bool background = false,
  }) {
    return lockFile(
      scope,
      prefsJsonFile,
      (handle) async {
        final model = PuroEnvPrefsModel();
        String? contents;
        if (handle.lengthSync() > 0) {
          contents = handle.readAllAsStringSync();
          model.mergeFromProto3Json(jsonDecode(contents));
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
                'use `puro engine prepare ${rootDir.parent.basename}` to create one',
      );
    }
  }
}

Future<PuroConfig> createPuroConfig({
  required Scope scope,
  required FileSystem fileSystem,
  required Directory puroRoot,
  required Directory homeDir,
  required CommandLineArgsConfig args,
  required bool firstRun,
  required bool enableShims,
}) async {
  final log = PuroLogger.of(scope);
  final globalPrefsJsonFile = scope.read(globalPrefsJsonFileProvider);
  final globalPrefs =
      await GlobalPrefsConfig.load(scope: scope, jsonFile: globalPrefsJsonFile);

  final currentDir = args.workingDir == null
      ? fileSystem.currentDirectory
      : fileSystem.directory(args.workingDir).absolute;

  var projectDir = args.projectDir;
  if (projectDir != null) projectDir = path.join(currentDir.path, projectDir);

  final gitExecutable = args.gitExecutable ?? 'git';
  if (!const LocalProcessManager().canRun(gitExecutable)) {
    final String instructions;
    if (Platform.isWindows) {
      instructions = 'getting it at https://git-scm.com/download/win';
    } else if (Platform.isLinux) {
      instructions = 'running `apt install git`';
    } else if (Platform.isMacOS) {
      instructions = 'running `brew install git`';
    } else {
      throw UnsupportedOSError();
    }
    throw CommandError(
      'Could not find git executable, consider $instructions',
    );
  }

  final absoluteProjectDir =
      projectDir == null ? null : fileSystem.directory(projectDir).absolute;

  var resultProjectDir = absoluteProjectDir ??
      findProjectDir(
        currentDir,
        'pubspec.yaml',
      );

  // Puro looks for a suitable project root in the following order:
  //   1. Directory specified in `--project`
  //   2. Closest parent directory with a `.puro.json`
  //   3. Closest grandparent directory with a `pubspec.yaml`
  //
  // If Puro finds a grandparent and tries to access the parentProjectDir with
  // dotfileForWriting, it throws an error indicating the selection is
  // ambiguous.
  final Directory? parentProjectDir = absoluteProjectDir ??
      findProjectDir(
        currentDir,
        ProjectConfig.dotfileName,
      ) ??
      (resultProjectDir != null
          ? findProjectDir(
              resultProjectDir.parent,
              'pubspec.yaml',
            )
          : null) ??
      resultProjectDir;

  resultProjectDir ??= parentProjectDir;

  log.d('puroRootDir: $puroRoot');
  puroRoot.createSync(recursive: true);
  puroRoot = fileSystem.directory(puroRoot.resolveSymbolicLinksSync()).absolute;
  log.d('puroRoot (resolved): $puroRoot');

  var environmentOverride = args.environmentOverride;
  var flutterStorageBaseUrl = args.flutterStorageBaseUrl;
  var pubCache = args.pubCache;
  var shouldSkipCacheSync = args.shouldSkipCacheSync;
  if (environmentOverride == null) {
    final flutterBin = Platform.environment['PURO_FLUTTER_BIN'];
    log.d('PURO_FLUTTER_BIN: $flutterBin');
    if (flutterBin != null) {
      final flutterBinDir = fileSystem.directory(flutterBin).absolute;
      final flutterSdkDir = flutterBinDir.parent;
      final envDir = flutterSdkDir.parent;
      final envsDir = envDir.parent;
      final otherPuroRoot = envsDir.parent;
      log.d('otherPuroRoot: $otherPuroRoot');
      log.d('puroRoot: $puroRoot');
      if (otherPuroRoot.pathEquals(puroRoot)) {
        environmentOverride = envDir.basename.toLowerCase();
        log.d('environmentOverride: $environmentOverride');
      }
    }
  }

  if (flutterStorageBaseUrl == null) {
    final override = Platform.environment['FLUTTER_STORAGE_BASE_URL'];
    if (override != null && override.isNotEmpty) {
      flutterStorageBaseUrl = override;
    }
  }
  flutterStorageBaseUrl ??=
      globalPrefs.flutterStorageBaseUrl ?? 'https://storage.googleapis.com';

  final pubCacheOverride = Platform.environment['PUB_CACHE'];
  if (pubCacheOverride != null && pubCacheOverride.isNotEmpty) {
    pubCache ??= pubCacheOverride;
  }
  pubCache ??= globalPrefs.pubCacheDir ??
      puroRoot.childDirectory('shared').childDirectory('pub_cache').path;

  shouldSkipCacheSync ??=
      Platform.environment['PURO_SKIP_CACHE_SYNC']?.isNotEmpty ?? false;

  final core = CoreConfig(
    fileSystem: fileSystem,
    gitExecutable: fileSystem.file(gitExecutable),
    puroRoot: puroRoot,
    homeDir: fileSystem.directory(homeDir),
    flutterGitUrl: args.flutterGitUrl ??
        globalPrefs.flutterGitUrl ??
        'https://github.com/flutter/flutter.git',
    engineGitUrl: args.engineGitUrl ??
        globalPrefs.engineGitUrl ??
        'https://github.com/flutter/engine.git',
    dartSdkGitUrl: args.dartSdkGitUrl ??
        globalPrefs.dartSdkGitUrl ??
        'https://github.com/dart-lang/sdk.git',
    releasesJsonUrl: Uri.parse(args.releasesJsonUrl ??
        globalPrefs.releasesJsonUrl ??
        '$flutterStorageBaseUrl/flutter_infra_release/releases/releases_${Platform.operatingSystem}.json'),
    flutterStorageBaseUrl: Uri.parse(flutterStorageBaseUrl),
    puroBuildsUrl: Uri.parse(globalPrefs.puroBuildsUrl ?? 'https://puro.dev/builds'),
    buildTarget: globalPrefs.puroBuildTarget != null
        ? PuroBuildTarget.fromString(globalPrefs.puroBuildTarget!)
        : PuroBuildTarget.query(),
    enableShims: enableShims,
  );

  final project = ProjectConfig(
    projectDir: resultProjectDir,
    parentProjectDir: parentProjectDir,
  );

  final config = PuroConfig(
    core: core,
    globalPrefs: globalPrefs,
    project: project,
    legacyPubCacheDir: fileSystem.directory(pubCache).absolute,
    legacyPubCache: args.legacyPubCache ?? !firstRun,
    environmentOverride: environmentOverride,
    shouldInstall: args.shouldInstall ?? globalPrefs.shouldInstall ?? true,
    shouldSkipCacheSync: shouldSkipCacheSync,
  );

  // Set parentConfig in project
  project.parentConfig = config;

  return config;
}

final _nameRegex = RegExp(r'^[_\-a-z][_\-a-z0-9]*$');
bool isValidName(String name) {
  return _nameRegex.hasMatch(name);
}

bool isValidVersion(String name) {
  final version = tryParseVersion(name);
  return version != null && name == '$version';
}

bool isValidEnvName(String name) {
  return isValidName(name) || isValidVersion(name);
}

final _commitHashRegex = RegExp(r'^[0-9a-f]{5,40}$');
bool isValidCommitHash(String commit) {
  return _commitHashRegex.hasMatch(commit);
}

Version? tryParseVersion(String text) {
  try {
    text = text.trim();
    return Version.parse(text.startsWith('v') ? text.substring(1) : text);
  } catch (exception) {
    return null;
  }
}

void ensureValidEnvName(String name) {
  if (isValidVersion(name)) return;
  for (var i = 0; i < name.length; i++) {
    final char = name[i];
    final codeUnit = char.codeUnitAt(0);
    if (char == '-' ||
        char == '_' ||
        (i != 0 && codeUnit >= 0x30 && codeUnit <= 0x39) ||
        (codeUnit >= 0x61 && codeUnit <= 0x7a)) {
      continue;
    }
    throw CommandError(
      'Unexpected `$char` at index $i of name `$name`\n'
      'Names must match pattern [_\\-a-z][_\\-a-z0-9]* or be a valid version',
    );
  }
  if (!isValidName(name)) {
    throw CommandError('Not a valid name: `$name`');
  }
}
