import 'dart:io';

import '../command.dart';
import '../command_result.dart';
import '../install/profile.dart';
import '../provider.dart';
import '../terminal.dart';
import '../version.dart';

/// Unified service for version-related operations.
///
/// This service provides a clean API for version checking and update detection,
/// decoupling the business logic from CLI parsing and command handling.
class VersionCommandService {
  const VersionCommandService();

  /// Gets version information and returns formatted messages.
  ///
  /// Returns a CommandResult with version info, update messages, and external installation warnings.
  Future<CommandResult> getVersionInfo({
    required Scope scope,
    required HavenCommandRunner runner,
  }) async {
    final havenVersion = await HavenVersion.of(scope);
    final externalMessage = await detectExternalFlutterInstallations(scope: scope);
    final updateMessage = await checkIfUpdateAvailable(
      scope: scope,
      runner: runner,
      alwaysNotify: true,
    );
    return BasicMessageResult.list([
      if (externalMessage != null) externalMessage,
      if (updateMessage != null) updateMessage,
      CommandMessage(
        'Haven ${havenVersion.semver} '
        '(${havenVersion.type.name}/${havenVersion.target.name})\n'
        'Dart ${Platform.version}',
        type: CompletionType.info,
      ),
    ]);
  }

  /// Prints just the version to stdout and exits.
  ///
  /// This method handles the --plain flag behavior.
  Future<void> printPlainVersion({
    required Scope scope,
    required HavenCommandRunner runner,
  }) async {
    final havenVersion = await HavenVersion.of(scope);
    Terminal.of(scope).flushStatus();
    await stderr.flush();
    stdout.write('${havenVersion.semver}');
    await runner.exitHaven(0);
  }
}
