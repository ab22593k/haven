import '../command.dart';
import '../command_result.dart';
import '../env/delete.dart';
import '../logger.dart';

class EnvRmCommand extends PuroCommand {
  EnvRmCommand() {
    argParser.addFlag(
      'force',
      abbr: 'f',
      help: 'Delete the environment regardless of whether it is in use',
      negatable: false,
    );
  }

  String? _deletedEnvName;

  @override
  void cleanup() {
    // Deletion is usually atomic, but if partial, log warning
    if (_deletedEnvName != null) {
      PuroLogger.of(scope).w('Deletion of $_deletedEnvName may be incomplete');
    }
  }

  @override
  final name = 'rm';

  @override
  final description = 'Deletes an environment';

  @override
  String? get argumentUsage => '<name>';

  @override
  Future<CommandResult> run() async {
    final name = unwrapSingleArgument();
    _deletedEnvName = name;
    return withErrorRecovery(() async {
      await deleteEnvironment(
        scope: scope,
        name: name,
        force: argResults!['force'] as bool,
      );
      return BasicMessageResult('Deleted environment `$name`');
    });
  }
}
