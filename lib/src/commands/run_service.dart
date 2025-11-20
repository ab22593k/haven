import 'dart:io';

import '../command.dart';
import '../env/command.dart';
import '../env/default.dart';
import '../provider.dart';

/// Unified service for run operations.
///
/// This service provides a clean API for running scripts in the current environment,
/// decoupling the business logic from CLI parsing and command handling.
class RunCommandService {
  const RunCommandService();

  /// Runs a script using dart run in the current environment.
  ///
  /// Forwards the provided arguments to dart run and exits with the process exit code.
  Future<void> runScript({
    required Scope scope,
    required HavenCommandRunner runner,
    required List<String> args,
  }) async {
    final environment = await getProjectEnvOrDefault(scope: scope);
    final exitCode = await runDartCommand(
      scope: scope,
      environment: environment,
      args: ['run', ...args],
      mode: ProcessStartMode.inheritStdio,
    );
    await runner.exitHaven(exitCode);
  }
}
