import '../command_result.dart';
import '../config/config.dart';
import '../config/project.dart';
import '../provider.dart';
import '../workspace/install.dart';
import 'create.dart';
import 'default.dart' as default_lib;
import 'delete.dart';
import 'list.dart';
import 'releases.dart';
import 'rename.dart';
import 'upgrade.dart';
import 'version.dart';

/// Provider for EnvServiceInterface.
final envServiceProvider = Provider<EnvServiceInterface>((scope) => const EnvService());

/// Unified service for environment operations.
///
/// This service provides a clean API for all environment lifecycle operations,
/// decoupling the business logic from CLI parsing and command handling.
abstract class EnvServiceInterface {
  /// Creates a new Flutter environment.
  ///
  /// Returns the created environment configuration.
  Future<EnvConfig> createEnv({
    required Scope scope,
    required String envName,
    String? channel,
    String? forkRemoteUrl,
    String? forkRef,
    String? version,
  });

  /// Lists all available environments.
  Future<ListEnvironmentResult> listEnvs({
    required Scope scope,
    bool showProjects = false,
    bool showDartVersion = false,
  });

  /// Switches to a different environment for the current project.
  ///
  /// Returns the switched-to environment configuration.
  Future<EnvConfig> switchEnv({
    required Scope scope,
    String? envName,
    bool? vscode,
    bool? intellij,
    required ProjectConfig projectConfig,
  });

  /// Gets the current global default environment name.
  Future<String> getDefaultEnvName({
    required Scope scope,
  });

  /// Sets the global default environment.
  ///
  /// If [envName] is null, returns the current default name.
  /// Otherwise, sets the default and returns a success message.
  Future<String> setDefaultEnv({
    required Scope scope,
    String? envName,
  });

  /// Deletes an environment.
  Future<void> deleteEnv({
    required Scope scope,
    required String envName,
    required bool force,
  });

  /// Renames an environment.
  Future<void> renameEnv({
    required Scope scope,
    required String oldName,
    required String newName,
  });

  /// Upgrades an environment to a new Flutter version.
  Future<EnvUpgradeResult> upgradeEnv({
    required Scope scope,
    required String envName,
    String? channel,
    String? version,
    bool force = false,
  });
}

class EnvService implements EnvServiceInterface {
  const EnvService();

  /// Creates a new Flutter environment.
  ///
  /// Returns the created environment configuration.
  @override
  Future<EnvConfig> createEnv({
    required Scope scope,
    required String envName,
    String? channel,
    String? forkRemoteUrl,
    String? forkRef,
    String? version,
  }) async {
    ensureValidEnvName(envName);

    if (forkRemoteUrl != null) {
      if (pseudoEnvironmentNames.contains(envName) || isValidVersion(envName)) {
        throw CommandError(
          'Cannot create fixed version `$envName` with a fork',
        );
      }
      return await createEnvironment(
        scope: scope,
        envName: envName,
        forkRemoteUrl: forkRemoteUrl,
        forkRef: forkRef,
      );
    } else {
      final flutterVersion = await FlutterVersion.query(
        scope: scope,
        version: version,
        channel: channel,
        defaultVersion: default_lib.isPseudoEnvName(envName) ? envName : 'stable',
      );
      return await createEnvironment(
        scope: scope,
        envName: envName,
        flutterVersion: flutterVersion,
      );
    }
  }

  /// Lists all available environments.
  @override
  Future<ListEnvironmentResult> listEnvs({
    required Scope scope,
    bool showProjects = false,
    bool showDartVersion = false,
  }) async {
    return await listEnvironments(
      scope: scope,
      showProjects: showProjects,
      showDartVersion: showDartVersion,
    );
  }

  /// Switches to a different environment for the current project.
  ///
  /// Returns the switched-to environment configuration.
  @override
  Future<EnvConfig> switchEnv({
    required Scope scope,
    String? envName,
    bool? vscode,
    bool? intellij,
    required ProjectConfig projectConfig,
  }) async {
    return await switchEnvironment(
      scope: scope,
      envName: envName,
      vscode: vscode,
      intellij: intellij,
      projectConfig: projectConfig,
    );
  }

  /// Gets the current global default environment name.
  @override
  Future<String> getDefaultEnvName({
    required Scope scope,
  }) async {
    return await default_lib.getDefaultEnvName(scope: scope);
  }

  /// Sets the global default environment.
  ///
  /// If [envName] is null, returns the current default name.
  /// Otherwise, sets the default and returns a success message.
  @override
  Future<String> setDefaultEnv({
    required Scope scope,
    String? envName,
  }) async {
    if (envName == null) {
      return await default_lib.getDefaultEnvName(scope: scope);
    }

    final config = PuroConfig.of(scope);
    final env = config.getEnv(envName);
    if (!env.exists) {
      if (default_lib.isPseudoEnvName(env.name)) {
        await createEnvironment(
          scope: scope,
          envName: env.name,
          flutterVersion: await FlutterVersion.query(
            scope: scope,
            version: env.name,
          ),
        );
      } else {
        throw CommandError('Environment `${env.name}` does not exist');
      }
    }
    await default_lib.setDefaultEnvName(scope: scope, envName: env.name);
    return 'Set global default environment to `${env.name}`';
  }

  /// Deletes an environment.
  @override
  Future<void> deleteEnv({
    required Scope scope,
    required String envName,
    required bool force,
  }) async {
    return await deleteEnvironment(
      scope: scope,
      name: envName,
      force: force,
    );
  }

  /// Renames an environment.
  @override
  Future<void> renameEnv({
    required Scope scope,
    required String oldName,
    required String newName,
  }) async {
    return await renameEnvironment(
      scope: scope,
      name: oldName,
      newName: newName,
    );
  }

  /// Upgrades an environment to a new Flutter version.
  @override
  Future<EnvUpgradeResult> upgradeEnv({
    required Scope scope,
    required String envName,
    String? channel,
    String? version,
    bool force = false,
  }) async {
    final config = PuroConfig.of(scope);
    final environment = config.getEnv(envName);

    if (!environment.exists && envName.toLowerCase() == 'puro') {
      throw CommandError(
        'Environment `$envName` does not exist\n'
        'Did you mean to run `puro upgrade-puro`?',
      );
    }
    environment.ensureExists();

    if (version == null && channel == null) {
      final prefs = await environment.readPrefs(scope: scope);
      if (prefs.hasDesiredVersion()) {
        final versionModel = prefs.desiredVersion;
        if (versionModel.hasBranch()) {
          version = prefs.desiredVersion.branch;
        }
      }
    }

    if (version == null && channel == null) {
      if (pseudoEnvironmentNames.contains(environment.name)) {
        version = environment.name;
      } else {
        throw CommandError(
          'No version provided and environment `${environment.name}` is not on a branch',
        );
      }
    }

    final toVersion = await FlutterVersion.query(
      scope: scope,
      version: version,
      channel: channel,
    );

    return await upgradeEnvironment(
      scope: scope,
      environment: environment,
      toVersion: toVersion,
      force: force,
    );
  }
}
