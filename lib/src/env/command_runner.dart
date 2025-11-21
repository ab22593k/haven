import 'dart:async';
import 'dart:io';

import 'package:clock/clock.dart';

import '../config/config.dart';
import '../logger.dart';
import '../process.dart';
import '../proto/haven.pb.dart';
import '../provider.dart';
import '../terminal.dart';
import 'default.dart';
import 'engine.dart';
import 'flutter_tool.dart';

/// Abstract base class for running commands in a haven environment.
/// Encapsulates common setup and execution logic to reduce direct EnvConfig dependencies.
abstract class EnvironmentCommandRunner {
  const EnvironmentCommandRunner();

  /// Runs the command with the given arguments in the environment.
  Future<int> runCommand({
    required Scope scope,
    required EnvConfig environment,
    required List<String> args,
    Stream<List<int>>? stdin,
    void Function(List<int>)? onStdout,
    void Function(List<int>)? onStderr,
    String? workingDirectory,
    ProcessStartMode mode = ProcessStartMode.normal,
  });

  /// Gets the executable path for the command.
  String getExecutablePath(FlutterConfig flutterConfig);

  /// Gets the command-specific arguments.
  Future<List<String>> getCommandArgs(
    Scope scope,
    EnvConfig environment,
    FlutterConfig flutterConfig,
    HavenEnvPrefsModel environmentPrefs,
    FlutterToolInfo? toolInfo,
    List<String> args,
  );

  /// Gets environment variables for the process.
  Map<String, String> getEnvironmentVariables(
    HavenConfig config,
    FlutterConfig flutterConfig,
  ) {
    return {
      'FLUTTER_ROOT': flutterConfig.sdkDir.path,
      'PUB_CACHE': config.legacyPubCacheDir.path,
    };
  }

  /// Performs any pre-run setup specific to the command.
  Future<void> preRunSetup(
    Scope scope,
    EnvConfig environment,
    List<String> args,
  ) async {}

  /// Performs any post-run cleanup specific to the command.
  Future<void> postRunCleanup(
    Scope scope,
    EnvConfig environment,
    List<String> args,
  ) async {}

  /// Determines if cache sync should be performed.
  bool shouldSyncCache(List<String> args) => !args.contains('--version');

  /// Runs the command with common setup and execution.
  Future<int> execute({
    required Scope scope,
    required EnvConfig environment,
    required List<String> args,
    Stream<List<int>>? stdin,
    void Function(List<int>)? onStdout,
    void Function(List<int>)? onStderr,
    String? workingDirectory,
    ProcessStartMode mode = ProcessStartMode.normal,
  }) async {
    final config = HavenConfig.of(scope);
    final flutterConfig = environment.flutter;
    final log = HVLogger.of(scope);
    final start = clock.now();

    final environmentPrefs = await environment.readPrefs(scope: scope);
    final toolInfo = await setUpFlutterTool(
      scope: scope,
      environment: environment,
      environmentPrefs: environmentPrefs,
    );

    log.v('Setting up tool took ${clock.now().difference(start).inMilliseconds}ms');

    await preRunSetup(scope, environment, args);

    Terminal.of(scope).flushStatus();

    final syncCache = shouldSyncCache(args);
    if (syncCache) {
      await trySyncFlutterCache(scope: scope, environment: environment);
    }

    final commandArgs = await getCommandArgs(
      scope,
      environment,
      flutterConfig,
      environmentPrefs,
      toolInfo,
      args,
    );

    final process = await startProcess(
      scope,
      getExecutablePath(flutterConfig),
      commandArgs,
      environment: getEnvironmentVariables(config, flutterConfig),
      workingDirectory: workingDirectory,
      mode: mode,
      rosettaWorkaround: true,
    );

    final disposeExitSignals = _setupExitSignals(mode);

    try {
      if (stdin != null) {
        unawaited(process.stdin.addStream(stdin));
      }
      final stdoutFuture = onStdout == null
          ? null
          : process.stdout.listen(onStdout).asFuture<void>();
      final stderrFuture = onStderr == null
          ? null
          : process.stderr.listen(onStderr).asFuture<void>();
      final exitCode = await process.exitCode;
      await stdoutFuture;
      await stderrFuture;

      if (syncCache) {
        await trySyncFlutterCache(scope: scope, environment: environment);
      }

      await postRunCleanup(scope, environment, args);

      return exitCode;
    } finally {
      await disposeExitSignals();
    }
  }
}

/// Command runner for Flutter commands.
class FlutterCommandRunner extends EnvironmentCommandRunner {
  const FlutterCommandRunner();

  @override
  Future<int> runCommand({
    required Scope scope,
    required EnvConfig environment,
    required List<String> args,
    Stream<List<int>>? stdin,
    void Function(List<int>)? onStdout,
    void Function(List<int>)? onStderr,
    String? workingDirectory,
    ProcessStartMode mode = ProcessStartMode.normal,
  }) {
    return execute(
      scope: scope,
      environment: environment,
      args: args,
      stdin: stdin,
      onStdout: onStdout,
      onStderr: onStderr,
      workingDirectory: workingDirectory,
      mode: mode,
    );
  }

  @override
  String getExecutablePath(FlutterConfig flutterConfig) {
    return flutterConfig.cache.dartSdk.dartExecutable.path;
  }

  @override
  Future<List<String>> getCommandArgs(
    Scope scope,
    EnvConfig environment,
    FlutterConfig flutterConfig,
    HavenEnvPrefsModel environmentPrefs,
    FlutterToolInfo? toolInfo,
    List<String> args,
  ) async {
    final shouldPrecompile =
        !environmentPrefs.hasPrecompileTool() || environmentPrefs.precompileTool;
    final quirks = await getToolQuirks(scope: scope, environment: environment);

    return [
      if (quirks.disableDartDev) '--disable-dart-dev',
      '--packages=${flutterConfig.flutterToolsPackageConfigJsonFile.path}',
      if (environment.flutterToolArgs.isNotEmpty)
        ...environment.flutterToolArgs.split(RegExp(r'\S+')),
      if (shouldPrecompile)
        toolInfo!.snapshotFile!.path
      else
        flutterConfig.flutterToolsScriptFile.path,
      ...args,
    ];
  }
}

/// Command runner for Dart commands.
class DartCommandRunner extends EnvironmentCommandRunner {
  const DartCommandRunner();

  @override
  Future<int> runCommand({
    required Scope scope,
    required EnvConfig environment,
    required List<String> args,
    Stream<List<int>>? stdin,
    void Function(List<int>)? onStdout,
    void Function(List<int>)? onStderr,
    String? workingDirectory,
    ProcessStartMode mode = ProcessStartMode.normal,
  }) {
    return execute(
      scope: scope,
      environment: environment,
      args: args,
      stdin: stdin,
      onStdout: onStdout,
      onStderr: onStderr,
      workingDirectory: workingDirectory,
      mode: mode,
    );
  }

  @override
  String getExecutablePath(FlutterConfig flutterConfig) {
    return flutterConfig.cache.dartSdk.dartExecutable.path;
  }

  @override
  Future<List<String>> getCommandArgs(
    Scope scope,
    EnvConfig environment,
    FlutterConfig flutterConfig,
    HavenEnvPrefsModel environmentPrefs,
    FlutterToolInfo? toolInfo,
    List<String> args,
  ) async {
    return args;
  }

  @override
  Future<void> preRunSetup(
    Scope scope,
    EnvConfig environment,
    List<String> args,
  ) async {
    final log = HVLogger.of(scope);
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
