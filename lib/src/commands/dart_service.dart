import 'dart:io';

import '../env/command.dart';
import '../env/default.dart';
import '../provider.dart';

/// Unified service for Dart command operations.
///
/// This service provides a clean API for Dart command forwarding,
/// decoupling the business logic from CLI parsing and command handling.
class DartCommandService {
  const DartCommandService();

  /// Executes a Dart command by forwarding arguments to the current environment.
  ///
  /// Returns the exit code from the dart process.
  Future<int> executeDartCommand({
    required Scope scope,
    required List<String> args,
  }) async {
    final environment = await getProjectEnvOrDefault(scope: scope);
    final exitCode = await runDartCommand(
      scope: scope,
      environment: environment,
      args: args,
      mode: ProcessStartMode.inheritStdio,
    );
    return exitCode;
  }
}
