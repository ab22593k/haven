import '../config/config.dart';
import '../provider.dart';
import 'flutter_tool.dart';

/// Service for handling Flutter tool setup.
class FlutterToolService {
  const FlutterToolService();

  /// Sets up the Flutter tool for the environment.
  Future<void> setUpTool({
    required Scope scope,
    required EnvConfig environment,
  }) async {
    await setUpFlutterTool(
      scope: scope,
      environment: environment,
    );
  }
}
