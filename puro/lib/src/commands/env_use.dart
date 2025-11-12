import '../command.dart';
import '../command_result.dart';
import '../config/config.dart';
import '../env/command.dart';
import '../logger.dart';
import '../terminal.dart';
import '../workspace/vscode.dart';

class EnvUseCommand extends PuroCommand {
  EnvUseCommand() {
    argParser.addFlag(
      'vscode',
      help: 'Enable or disable generation of VSCode configs',
    );
    argParser.addFlag(
      'intellij',
      help: 'Enable or disable generation of IntelliJ (or Android Studio) configs',
    );
    argParser.addFlag(
      'global',
      abbr: 'g',
      help: 'Set the global default to the provided environment',
      negatable: false,
    );
  }

  String? _switchedEnvName;

  @override
  void cleanup() {
    if (_switchedEnvName != null) {
      PuroLogger.of(scope).w(
          'Switch to $_switchedEnvName failed; environment state may be inconsistent');
    }
  }

  @override
  final name = 'use';

  @override
  final description = 'Selects an environment to use in the current project';

  @override
  String? get argumentUsage => '<name>';

  @override
  Future<CommandResult> run() async {
    const service = EnvCommandService();
    return withErrorRecovery(() async {
      final args = unwrapArguments(atMost: 1);
      final config = PuroConfig.of(scope);
      final envName = args.isEmpty ? null : args.first;

      if (argResults!['global'] as bool) {
        final message = await service.setDefaultEnv(
          scope: scope,
          envName: envName,
        );
        return BasicMessageResult(
          message,
          type: envName == null ? CompletionType.info : CompletionType.success,
        );
      }

      var vscodeOverride =
          argResults!.wasParsed('vscode') ? argResults!['vscode'] as bool : null;
      if (vscodeOverride == null && await isRunningInVscode(scope: scope)) {
        vscodeOverride = true;
      }

      final environment = await service.switchEnv(
        scope: scope,
        envName: envName,
        vscode: vscodeOverride,
        intellij:
            argResults!.wasParsed('intellij') ? argResults!['intellij'] as bool : null,
        projectConfig: config.project,
      );
      _switchedEnvName = environment.name;
      return BasicMessageResult(
        'Switched to environment `${environment.name}`',
      );
    });
  }
}
