import 'dart:io';

import '../env/command.dart';
import '../env/default.dart';
import '../provider.dart';

/// Unified service for Pub command operations.
///
/// This service provides a clean API for Pub command forwarding,
/// decoupling the business logic from CLI parsing and command handling.
class PubCommandService {
  const PubCommandService();

  /// Executes a Pub command by forwarding arguments to the current environment.
  ///
  /// Returns the exit code from the flutter pub process.
  Future<int> executePubCommand({
    required Scope scope,
    required List<String> args,
  }) async {
    final environment = await getProjectEnvOrDefault(scope: scope);
    final exitCode = await runFlutterCommand(
      scope: scope,
      environment: environment,
      args: ['pub', ...args],
      mode: ProcessStartMode.inheritStdio,
    );
    return exitCode;
  }
}