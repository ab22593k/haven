import 'dart:async';
import 'dart:io';

import 'package:clock/clock.dart';

import '../command_result.dart';
import '../config/config.dart';
import '../config/project.dart';
import '../logger.dart';
import '../process.dart';
import '../provider.dart';
import '../terminal.dart';
import '../workspace/install.dart';
import 'create.dart';
import 'default.dart';
import 'delete.dart';
import 'engine.dart';
import 'flutter_tool.dart';
import 'list.dart';
import 'releases.dart';
import 'rename.dart';
import 'upgrade.dart';
import 'version.dart';

Future<int> runFlutterCommand({
  required Scope scope,
  required EnvConfig environment,
  required List<String> args,
  Stream<List<int>>? stdin,
  void Function(List<int>)? onStdout,
  void Function(List<int>)? onStderr,
  String? workingDirectory,
  ProcessStartMode mode = ProcessStartMode.normal,
}) async {
  final config = PuroConfig.of(scope);
  final flutterConfig = environment.flutter;
  final log = PuroLogger.of(scope);
  final start = clock.now();
  final environmentPrefs = await environment.readPrefs(scope: scope);
  final toolInfo = await setUpFlutterTool(
    scope: scope,
    environment: environment,
    environmentPrefs: environmentPrefs,
  );
  log.v(
    'Setting up flutter tool took ${clock.now().difference(start).inMilliseconds}ms',
  );
  Terminal.of(scope).flushStatus();
  final dartPath = flutterConfig.cache.dartSdk.dartExecutable.path;
  final shouldPrecompile =
      !environmentPrefs.hasPrecompileTool() || environmentPrefs.precompileTool;
  final quirks = await getToolQuirks(scope: scope, environment: environment);
  final syncCache = !args.contains('--version');
  if (syncCache) {
    await trySyncFlutterCache(scope: scope, environment: environment);
  }
  final flutterProcess = await startProcess(
    scope,
    dartPath,
    [
      if (quirks.disableDartDev) '--disable-dart-dev',
      '--packages=${flutterConfig.flutterToolsPackageConfigJsonFile.path}',
      if (environment.flutterToolArgs.isNotEmpty)
        ...environment.flutterToolArgs.split(RegExp(r'\S+')),
      if (shouldPrecompile)
        toolInfo.snapshotFile!.path
      else
        flutterConfig.flutterToolsScriptFile.path,
      ...args,
    ],
    environment: {
      'FLUTTER_ROOT': flutterConfig.sdkDir.path,
      'PUB_CACHE': config.legacyPubCacheDir.path,
    },
    workingDirectory: workingDirectory,
    mode: mode,
    rosettaWorkaround: true,
  );

  final disposeExitSignals = _setupExitSignals(mode);

  try {
    if (stdin != null) {
      unawaited(flutterProcess.stdin.addStream(stdin));
    }
    final stdoutFuture = onStdout == null
        ? null
        : flutterProcess.stdout.listen(onStdout).asFuture<void>();
    final stderrFuture = onStderr == null
        ? null
        : flutterProcess.stderr.listen(onStderr).asFuture<void>();
    final exitCode = await flutterProcess.exitCode;
    await stdoutFuture;
    await stderrFuture;

    if (syncCache) {
      await trySyncFlutterCache(scope: scope, environment: environment);
    }
    return exitCode;
  } finally {
    await disposeExitSignals();
  }
}

Future<int> runDartCommand({
  required Scope scope,
  required EnvConfig environment,
  required List<String> args,
  Stream<List<int>>? stdin,
  void Function(List<int>)? onStdout,
  void Function(List<int>)? onStderr,
  String? workingDirectory,
  ProcessStartMode mode = ProcessStartMode.normal,
}) async {
  final config = PuroConfig.of(scope);
  final flutterConfig = environment.flutter;
  final log = PuroLogger.of(scope);
  final start = clock.now();
  final environmentPrefs = await environment.readPrefs(scope: scope);
  await setUpFlutterTool(
    scope: scope,
    environment: environment,
    environmentPrefs: environmentPrefs,
  );
  log.v(
    'Setting up dart took ${clock.now().difference(start).inMilliseconds}ms',
  );
  final nonOptionArgs = args.where((e) => !e.startsWith('-')).toList();
  if (nonOptionArgs.length >= 2 &&
      nonOptionArgs[0] == 'pub' &&
      nonOptionArgs[1] == 'global') {
    final defaultEnvName = await getDefaultEnvName(scope: scope);
    if (environment.name != defaultEnvName) {
      log.w(
        'Warning: `pub global` should only be used with the default environment `$defaultEnvName`, '
        'your current environment is `${environment.name}`\n'
        'Due to a limitation in Dart, globally activated scripts can only use the default dart runtime',
      );
    }
  }
  Terminal.of(scope).flushStatus();
  final dartProcess = await startProcess(
    scope,
    flutterConfig.cache.dartSdk.dartExecutable.path,
    args,
    environment: {
      'FLUTTER_ROOT': flutterConfig.sdkDir.path,
      'PUB_CACHE': config.legacyPubCacheDir.path,
    },
    workingDirectory: workingDirectory,
    mode: mode,
    rosettaWorkaround: true,
  );

  final disposeExitSignals = _setupExitSignals(mode);

  try {
    if (stdin != null) {
      unawaited(dartProcess.stdin.addStream(stdin));
    }
    final stdoutFuture =
        onStdout == null ? null : dartProcess.stdout.listen(onStdout).asFuture<void>();
    final stderrFuture =
        onStderr == null ? null : dartProcess.stderr.listen(onStderr).asFuture<void>();
    final exitCode = await dartProcess.exitCode;
    await stdoutFuture;
    await stderrFuture;

    return exitCode;
  } finally {
    await disposeExitSignals();
  }
}

/// Capture SIGINT and SIGTERM signals. If we don't capture them, the parent
/// process will exit, so the dart command won't have a chance to handle them.
/// Some CLI apps might want to behave differently when they receive these
/// signals.
Future<void> Function() _setupExitSignals(ProcessStartMode mode) {
  StreamSubscription<ProcessSignal>? sigIntSub, sigTermSub;

  if (mode == ProcessStartMode.inheritStdio) {
    sigIntSub = ProcessSignal.sigint.watch().listen((_) {});

    // SIGTERM is not supported on Windows. Attempting to register a SIGTERM
    // handler raises an exception.
    if (!Platform.isWindows) {
      sigTermSub = ProcessSignal.sigterm.watch().listen((_) {});
    }
  }

  // Cleanup function
  return () async {
    // cleanup signal subscriptions
    await sigIntSub?.cancel();
    await sigTermSub?.cancel();
  };
}

/// Unified service for environment operations.
///
/// This service provides a clean API for all environment lifecycle operations,
/// decoupling the business logic from CLI parsing and command handling.
class EnvCommandService {
  const EnvCommandService();

  /// Creates a new Flutter environment.
  ///
  /// Returns the created environment configuration.
  Future<EnvConfig> createEnv({
    required Scope scope,
    required String envName,
    String? channel,
    String? forkRemoteUrl,
    String? forkRef,
    String? version,
  }) async {
    ensureValidEnvName(envName);

    if (forkRemoteUrl != null) {
      if (pseudoEnvironmentNames.contains(envName) || isValidVersion(envName)) {
        throw CommandError(
          'Cannot create fixed version `$envName` with a fork',
        );
      }
      return await createEnvironment(
        scope: scope,
        envName: envName,
        forkRemoteUrl: forkRemoteUrl,
        forkRef: forkRef,
      );
    } else {
      final flutterVersion = await FlutterVersion.query(
        scope: scope,
        version: version,
        channel: channel,
        defaultVersion: isPseudoEnvName(envName) ? envName : 'stable',
      );
      return await createEnvironment(
        scope: scope,
        envName: envName,
        flutterVersion: flutterVersion,
      );
    }
  }

  /// Lists all available environments.
  Future<ListEnvironmentResult> listEnvs({
    required Scope scope,
    bool showProjects = false,
    bool showDartVersion = false,
  }) async {
    return await listEnvironments(
      scope: scope,
      showProjects: showProjects,
      showDartVersion: showDartVersion,
    );
  }

  /// Switches to a different environment for the current project.
  ///
  /// Returns the switched-to environment configuration.
  Future<EnvConfig> switchEnv({
    required Scope scope,
    String? envName,
    bool? vscode,
    bool? intellij,
    required ProjectConfig projectConfig,
  }) async {
    return await switchEnvironment(
      scope: scope,
      envName: envName,
      vscode: vscode,
      intellij: intellij,
      projectConfig: projectConfig,
    );
  }

  /// Gets the current global default environment name.
  Future<String> getDefaultEnvName({
    required Scope scope,
  }) async {
    return await getDefaultEnvName(scope: scope);
  }

  /// Sets the global default environment.
  ///
  /// If [envName] is null, returns the current default name.
  /// Otherwise, sets the default and returns a success message.
  Future<String> setDefaultEnv({
    required Scope scope,
    String? envName,
  }) async {
    if (envName == null) {
      return await getDefaultEnvName(scope: scope);
    }

    final config = PuroConfig.of(scope);
    final env = config.getEnv(envName);
    if (!env.exists) {
      if (isPseudoEnvName(env.name)) {
        await createEnvironment(
          scope: scope,
          envName: env.name,
          flutterVersion: await FlutterVersion.query(
            scope: scope,
            version: env.name,
          ),
        );
      } else {
        throw CommandError('Environment `${env.name}` does not exist');
      }
    }
    await setDefaultEnvName(scope: scope, envName: env.name);
    return 'Set global default environment to `${env.name}`';
  }

  /// Deletes an environment.
  Future<void> deleteEnv({
    required Scope scope,
    required String envName,
    required bool force,
  }) async {
    return await deleteEnvironment(
      scope: scope,
      name: envName,
      force: force,
    );
  }

  /// Renames an environment.
  Future<void> renameEnv({
    required Scope scope,
    required String oldName,
    required String newName,
  }) async {
    return await renameEnvironment(
      scope: scope,
      name: oldName,
      newName: newName,
    );
  }

  /// Upgrades an environment to a new Flutter version.
  Future<EnvUpgradeResult> upgradeEnv({
    required Scope scope,
    required String envName,
    String? channel,
    String? version,
    bool force = false,
  }) async {
    final config = PuroConfig.of(scope);
    final environment = config.getEnv(envName);

    if (!environment.exists && envName.toLowerCase() == 'puro') {
      throw CommandError(
        'Environment `$envName` does not exist\n'
        'Did you mean to run `puro upgrade-puro`?',
      );
    }
    environment.ensureExists();

    if (version == null && channel == null) {
      final prefs = await environment.readPrefs(scope: scope);
      if (prefs.hasDesiredVersion()) {
        final versionModel = prefs.desiredVersion;
        if (versionModel.hasBranch()) {
          version = prefs.desiredVersion.branch;
        }
      }
    }

    if (version == null && channel == null) {
      if (pseudoEnvironmentNames.contains(environment.name)) {
        version = environment.name;
      } else {
        throw CommandError(
          'No version provided and environment `${environment.name}` is not on a branch',
        );
      }
    }

    final toVersion = await FlutterVersion.query(
      scope: scope,
      version: version,
      channel: channel,
    );

    return await upgradeEnvironment(
      scope: scope,
      environment: environment,
      toVersion: toVersion,
      force: force,
    );
  }
}
