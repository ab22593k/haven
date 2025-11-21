import '../config/config.dart';
import '../provider.dart';
import 'env_shims.dart';

/// Service for handling environment shims.
class ShimService {
  const ShimService();

  /// Installs environment shims.
  Future<void> installShims({
    required Scope scope,
    required EnvConfig environment,
  }) async {
    await installEnvShims(scope: scope, environment: environment);
  }

  /// Uninstalls environment shims.
  Future<void> uninstallShims({
    required Scope scope,
    required EnvConfig environment,
  }) async {
    await uninstallEnvShims(scope: scope, environment: environment);
  }
}
