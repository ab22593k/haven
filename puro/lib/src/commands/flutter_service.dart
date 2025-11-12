import 'dart:io';

import '../command.dart';
import '../env/command.dart';
import '../env/default.dart';
import '../logger.dart';
import '../provider.dart';
import '../terminal.dart';

/// Unified service for Flutter command operations.
///
/// This service provides a clean API for Flutter command forwarding and special cases,
/// decoupling the business logic from CLI parsing and command handling.
class FlutterCommandService {
  const FlutterCommandService();

  /// Executes a Flutter command with special handling for intercepted commands.
  ///
  /// Returns the exit code from the flutter process, or handles special commands internally.
  Future<int> executeFlutterCommand({
    required Scope scope,
    required PuroCommandRunner runner,
    required List<String> args,
  }) async {
    final log = PuroLogger.of(scope);
    final environment = await getProjectEnvOrDefault(scope: scope);
    log.v('Flutter SDK: ${environment.flutter.sdkDir.path}');

    final nonOptionArgs = args.where((e) => !e.startsWith('-')).toList();

    // Handle special intercepted commands
    if (nonOptionArgs.isNotEmpty) {
      if (nonOptionArgs.first == 'upgrade') {
        runner.addMessage(
          'Using puro to upgrade flutter',
          type: CompletionType.info,
        );
        await runner.run(['upgrade', environment.name]);
        // Since runner.run returns a CommandResult, we need to exit with success
        // The original code used exit(exitCode), but since we're in a service,
        // we'll return 0 for success
        return 0;
      } else if (nonOptionArgs.first == 'channel' && nonOptionArgs.length > 1) {
        runner.addMessage(
          'Using puro to switch flutter channel',
          type: CompletionType.info,
        );
        final channelArgs =
            args.where((e) => !e.startsWith('-')).skip(1).take(1).toList();
        if (channelArgs.isNotEmpty) {
          await runner.run(['upgrade', channelArgs.first]);
          return 0;
        }
      }
    }

    // Forward to flutter command
    final exitCode = await runFlutterCommand(
      scope: scope,
      environment: environment,
      args: args,
      // inheritStdio is useful because it allows Flutter to detect the
      // terminal, otherwise it won't show any colors.
      mode: ProcessStartMode.inheritStdio,
    );

    return exitCode;
  }
}
