import '../config/config.dart';
import '../provider.dart';
import 'build_env.dart';
import 'patch.dart';
import 'prepare.dart';
import 'visual_studio.dart';
import 'worker.dart';

/// Unified service for engine/toolchain operations.
///
/// This service provides a clean API for all engine-related operations,
/// decoupling the business logic from CLI parsing and command handling.
class EngineCommandService {
  const EngineCommandService();

  /// Installs system dependencies required for engine building.
  Future<void> prepareSystemDeps({required Scope scope}) async {
    return await prepareEngineSystemDeps(scope: scope);
  }

  /// Prepares an environment for building the engine.
  Future<void> prepareEngine({
    required Scope scope,
    required EnvConfig environment,
    String? ref,
    String? forkRemoteUrl,
    bool force = false,
  }) async {
    return await prepareEngine(
      scope: scope,
      environment: environment,
      ref: ref,
      forkRemoteUrl: forkRemoteUrl,
      force: force,
    );
  }

  /// Runs a shell with the proper environment variables for building the engine.
  Future<int> runBuildShell({
    required Scope scope,
    List<String>? command,
    EnvConfig? environment,
  }) async {
    return await runBuildEnvShell(
      scope: scope,
      command: command,
      environment: environment,
    );
  }

  /// Gets the environment variables needed for building the engine.
  Future<Map<String, String>> getBuildEnvVars({required Scope scope}) async {
    return await getEngineBuildEnvVars(scope: scope);
  }

  /// Ensures Visual Studio is installed and configured for engine building.
  Future<VisualStudio> ensureVisualStudio({required Scope scope}) async {
    return await ensureVisualStudioInstalled(scope: scope);
  }

  /// Installs depot tools required for engine development.
  Future<void> installDepotTools({required Scope scope}) async {
    return await installDepotTools(scope: scope);
  }

  /// Applies patches to the engine source.
  Future<void> applyPatches({
    required Scope scope,
    required EnvConfig environment,
  }) async {
    final engineCommit = environment.flutter.engineVersion;
    if (engineCommit != null) {
      return await applyEnginePatches(scope: scope, engineCommit: engineCommit);
    }
  }
}
