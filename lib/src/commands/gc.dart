import '../command.dart';
import '../command_result.dart';
import 'gc_service.dart';

class GcCommand extends HavenCommand {
  @override
  final name = 'gc';

  @override
  final description = 'Cleans up unused caches';

  @override
  Future<CommandResult> run() async {
    const service = GcCommandService();
    return service.performGarbageCollection(
      scope: scope,
      maxUnusedCaches: 0,
      maxUnusedFlutterTools: 0,
    );
  }
}
