import '../command.dart';
import '../command_result.dart';
import '../env/service.dart';

class EnvRenameCommand extends PuroCommand {
  @override
  final name = 'rename';

  @override
  final description = 'Renames an environment';

  @override
  String? get argumentUsage => '<name> <new name>';

  @override
  Future<CommandResult> run() async {
    const service = EnvService();
    final args = unwrapArguments(exactly: 2);
    final name = args[0];
    final newName = args[1];
    await service.renameEnv(
      scope: scope,
      oldName: name,
      newName: newName,
    );
    return BasicMessageResult('Renamed environment `$name` to `$newName`');
  }
}
