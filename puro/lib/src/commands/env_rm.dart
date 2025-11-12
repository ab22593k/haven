import '../command.dart';
import '../command_result.dart';
import '../env/command.dart';

class EnvRmCommand extends PuroCommand {
  EnvRmCommand() {
    argParser.addFlag(
      'force',
      abbr: 'f',
      help: 'Delete the environment regardless of whether it is in use',
      negatable: false,
    );
  }

  @override
  final name = 'rm';

  @override
  final description = 'Deletes an environment';

  @override
  String? get argumentUsage => '<name>';

  @override
  Future<CommandResult> run() async {
    const service = EnvCommandService();
    final name = unwrapSingleArgument();
    return withErrorRecovery(() async {
      await service.deleteEnv(
        scope: scope,
        envName: name,
        force: argResults!['force'] as bool,
      );
      return BasicMessageResult('Deleted environment `$name`');
    });
  }
}
