import 'package:clock/clock.dart';

import '../command_result.dart';
import '../config/config.dart';
import '../file_lock.dart';
import '../git.dart';
import '../logger.dart';
import '../provider.dart';
import 'default.dart';
import 'engine_precache_service.dart';
import 'file_system_service.dart';
import 'flutter_tool_service.dart';
import 'git_operations_service.dart';
import 'shim_service.dart';
import 'transaction.dart';
import 'version.dart';

/// Updates the engine version file, to replicate the functionality of
/// https://github.com/flutter/flutter/blob/master/bin/internal/update_engine_version.sh
/// See script details at https://github.com/flutter/flutter/issues/163896
Future<void> updateEngineVersionFile({
  required Scope scope,
  required FlutterConfig flutterConfig,
}) async {
  if (!flutterConfig.hasEngine) {
    // Not a monolithic engine, nothing to do.
    return;
  }

  final git = GitClient.of(scope);
  final remotes = await git.getRemotes(repository: flutterConfig.sdkDir);

  final String commit;

  // Check if this is a fork (has an upstream)
  if (remotes.containsKey('upstream')) {
    // Fetch, otherwise merge-base will fail on the first run
    if (!await git.checkCommitExists(
      repository: flutterConfig.sdkDir,
      commit: 'upstream/master',
    )) {
      await git.fetch(repository: flutterConfig.sdkDir, remote: 'upstream', all: true);
    }
    commit = await git.mergeBase(
      repository: flutterConfig.sdkDir,
      ref1: 'HEAD',
      ref2: 'upstream/master',
    );
  } else {
    commit = await git.mergeBase(
      repository: flutterConfig.sdkDir,
      ref1: 'HEAD',
      ref2: 'origin/master',
    );
  }

  await flutterConfig.engineVersionFile.writeAsString('$commit\n');
}

Future<String?> getEngineVersion({
  required Scope scope,
  required FlutterConfig flutterConfig,
}) async {
  final git = GitClient.of(scope);
  final result = await git.tryCat(
    repository: flutterConfig.sdkDir,
    path: 'bin/internal/engine.version',
    ref: 'HEAD',
  );
  if (result == null) {
    await updateEngineVersionFile(scope: scope, flutterConfig: flutterConfig);
  }

  return flutterConfig.engineVersion;
}

/// Service for creating haven environments.
class EnvironmentCreator {
  const EnvironmentCreator();

  /// Creates a new haven environment named [envName] and installs flutter.
  ///
  /// This operation is transactional: on failure, any created env directory,
  /// written prefs, cloned framework, or installed shims are rolled back.
  /// No half-created environments are left behind.
  Future<EnvConfig> createEnvironment({
    required Scope scope,
    required String envName,
    FlutterVersion? flutterVersion,
    String? forkRemoteUrl,
    String? forkRef,
  }) async {
    if ((flutterVersion == null) == (forkRemoteUrl == null)) {
      throw AssertionError(
        'Exactly one of flutterVersion and forkRemoteUrl should be provided',
      );
    }

    if (isValidVersion(envName) &&
        (flutterVersion == null ||
            flutterVersion.version == null ||
            envName != '${flutterVersion.version}')) {
      throw CommandError(
        'Cannot create environment $envName with version ${flutterVersion?.name}',
      );
    }

    final config = HavenConfig.of(scope);
    final log = HVLogger.of(scope);
    final git = GitClient.of(scope);
    final environment = config.getEnv(envName);

    log.v('Creating a new environment in ${environment.envDir.path}');

    final existing = await environment.envDir.exists();

    if (existing && await environment.flutterDir.exists()) {
      final commit = await git.tryGetCurrentCommitHash(
        repository: environment.flutterDir,
      );
      if (commit != null) {
        throw CommandError(
          'Environment `$envName` already exists, use `haven upgrade` to switch '
          'version or `haven rm` before trying again',
        );
      }
    }

    await environment.updateLockFile.parent.create(recursive: true);
    return await lockFile(scope, environment.updateLockFile, (lockHandle) async {
      return await EnvTransaction.run(
        scope: scope,
        body: (tx) async {
          // Create env directory
          await tx.step(
            label: 'create environment directory',
            action: () async => await const FileSystemService()
                .createEnvironmentDirectory(environment.envDir),
            rollback: () async => await environment.envDir.delete(recursive: true),
          );

          // Update prefs
          final prefsUpdate = await const FileSystemService().preparePrefsUpdate(
            scope: scope,
            environment: environment,
            flutterVersion: flutterVersion,
          );
          await tx.step(
            label: 'update environment prefs',
            action: prefsUpdate.action,
            rollback: prefsUpdate.rollback,
          );

          final startTime = clock.now();
          DateTime? cacheEngineTime;

          final engineTask = runOptional(
            scope,
            'Pre-caching engine',
            () async {
              await const EnginePrecacheService().precacheEngine(
                scope: scope,
                commit: flutterVersion!.commit,
              );
              cacheEngineTime = clock.now();
            },
            // The user probably already has flutter cached so cloning forks will be
            // fast, no point in optimizing this.
            skip: forkRemoteUrl != null,
          );

          // Clone flutter
          await tx.step(
            label: 'clone flutter repository',
            action: () async {
              await const GitOperationsService().cloneFlutterWithSharedRefs(
                scope: scope,
                repository: environment.flutterDir,
                environment: environment,
                flutterVersion: flutterVersion,
                forkRemoteUrl: forkRemoteUrl,
                forkRef: forkRef,
              );
            },
            rollback: () async => await environment.flutterDir.delete(recursive: true),
          );

          // Replace flutter/dart with shims
          await tx.step(
            label: 'install environment shims',
            action: () async {
              await const ShimService().installShims(
                scope: scope,
                environment: environment,
              );
            },
            rollback: () async {
              await const ShimService().uninstallShims(
                scope: scope,
                environment: environment,
              );
            },
          );

          final cloneTime = clock.now();

          await engineTask;

          if (cacheEngineTime != null) {
            final wouldveTaken =
                (cloneTime.difference(startTime)) +
                (cacheEngineTime!.difference(startTime));
            final took = clock.now().difference(startTime);
            log.v(
              'Saved ${(wouldveTaken - took).inMilliseconds}ms by pre-caching engine',
            );
          }

          // In case we are creating the default environment
          await tx.step(
            label: 'update default env symlink',
            action: () async => await updateDefaultEnvSymlink(scope: scope),
            rollback:
                null, // Symlink update might not need rollback, or implement if possible
          );

          // Set up engine and compile tool
          await tx.step(
            label: 'set up flutter tool',
            action: () async => await const FlutterToolService().setUpTool(
              scope: scope,
              environment: environment,
            ),
            rollback: null, // Tool setup is final, assume it succeeds or log
          );

          return environment;
        },
      );
    });
  }
}

/// Creates a new haven environment named [envName] and installs flutter.
///
/// This operation is transactional: on failure, any created env directory,
/// written prefs, cloned framework, or installed shims are rolled back.
/// No half-created environments are left behind.
Future<EnvConfig> createEnvironment({
  required Scope scope,
  required String envName,
  FlutterVersion? flutterVersion,
  String? forkRemoteUrl,
  String? forkRef,
}) async {
  return const EnvironmentCreator().createEnvironment(
    scope: scope,
    envName: envName,
    flutterVersion: flutterVersion,
    forkRemoteUrl: forkRemoteUrl,
    forkRef: forkRef,
  );
}
