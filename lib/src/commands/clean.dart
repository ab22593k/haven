import '../command.dart';
import '../command_result.dart';
import '../config/config.dart';
import 'workspace_service.dart';

class CleanCommand extends HavenCommand {
  @override
  final name = 'clean';

  @override
  final description =
      'Deletes Haven configuration files from the current project and restores IDE settings';

  @override
  bool get takesArguments => false;

  @override
  Future<CommandResult> run() async {
    final config = HavenConfig.of(scope);
    const service = WorkspaceCommandService();
    return service.cleanWorkspace(
      scope: scope,
      projectConfig: config.project,
    );
  }
}
