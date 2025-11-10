import 'dart:io';

import 'package:file/file.dart';
import 'package:path/path.dart' as path;
import 'package:process/process.dart';
import 'package:pub_semver/pub_semver.dart';

import '../command_line_args_config.dart';
import '../command_result.dart';
import '../config/core.dart';
import '../config/prefs.dart';
import '../extensions.dart';
import '../logger.dart';
import '../provider.dart';
import '../version.dart';
import 'config.dart';
import 'project.dart';

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
