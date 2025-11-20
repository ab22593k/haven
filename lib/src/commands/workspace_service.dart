import '../command_result.dart';
import '../config/project.dart';
import '../provider.dart';

/// Unified service for workspace operations.
///
/// This service provides a clean API for workspace-related operations,
/// decoupling the business logic from CLI parsing and command handling.
class WorkspaceCommandService {
  const WorkspaceCommandService();

  /// Cleans the workspace by removing haven configuration files and restoring IDE settings.
  ///
  /// Returns a CommandResult indicating the operation was successful.
  Future<CommandResult> cleanWorkspace({
    required Scope scope,
    required ProjectConfig projectConfig,
  }) async {
    await cleanWorkspace(
      scope: scope,
      projectConfig: projectConfig,
    );
    return BasicMessageResult('Removed haven from current project');
  }
}
