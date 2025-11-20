import '../command_result.dart';
import '../env/gc.dart';
import '../extensions.dart';
import '../provider.dart';

/// Unified service for garbage collection operations.
///
/// This service provides a clean API for garbage collection operations,
/// decoupling the business logic from CLI parsing and command handling.
class GcCommandService {
  const GcCommandService();

  /// Performs garbage collection and returns a formatted result.
  ///
  /// Returns a CommandResult with information about the cleanup performed.
  Future<CommandResult> performGarbageCollection({
    required Scope scope,
    int maxUnusedCaches = 0,
    int maxUnusedFlutterTools = 0,
  }) async {
    final bytes = await collectGarbage(
      scope: scope,
      maxUnusedCaches: maxUnusedCaches,
      maxUnusedFlutterTools: maxUnusedFlutterTools,
    );
    if (bytes == 0) {
      return BasicMessageResult('Nothing to clean up');
    } else {
      return BasicMessageResult(
        'Cleaned up caches and reclaimed ${bytes.prettyAbbr(metric: true)}B',
      );
    }
  }
}
