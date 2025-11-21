import 'dart:io';

import '../command_result.dart';
import '../config/config.dart';
import '../config/prefs.dart';
import '../file_lock.dart';
import '../provider.dart';
import 'create.dart';
import 'releases.dart';
import 'transaction.dart';
import 'version.dart';

export '../config/prefs.dart' show globalPrefsJsonFileProvider;

bool isPseudoEnvName(String name) {
  return pseudoEnvironmentNames.contains(name) || isValidVersion(name);
}

Future<EnvConfig> _getPseudoEnvironment({
  required Scope scope,
  required String envName,
}) async {
  final config = HavenConfig.of(scope);
  final environment = config.getEnv(envName);
  if (!environment.exists) {
    await createEnvironment(
      scope: scope,
      envName: environment.name,
      flutterVersion: await FlutterVersion.query(
        scope: scope,
        version: environment.name,
      ),
    );
  }
  return environment;
}

Future<EnvConfig> getProjectEnvOrDefault({
  required Scope scope,
  String? envName,
}) async {
  final config = HavenConfig.of(scope);
  if (envName != null) {
    final environment = config.getEnv(envName);
    if (!environment.exists) {
      if (isPseudoEnvName(environment.name)) {
        return _getPseudoEnvironment(scope: scope, envName: envName);
      }
      environment.ensureExists();
    }
    return environment;
  }
  var env = config.tryGetProjectEnv();
  if (env == null) {
    final override = config.environmentOverride;
    if (override != null) {
      if (isPseudoEnvName(override)) {
        return _getPseudoEnvironment(scope: scope, envName: override);
      }
      throw CommandError(
        'Selected environment `${config.environmentOverride}` does not exist',
      );
    }
    final envName = await getDefaultEnvName(scope: scope);
    if (isPseudoEnvName(envName)) {
      return _getPseudoEnvironment(scope: scope, envName: envName);
    }
    env = config.getEnv(envName);
    if (!env.exists) {
      throw CommandError(
        'No environment selected and default environment `$envName` does not exist',
      );
    }
  }
  return env;
}

Future<String> getDefaultEnvName({required Scope scope}) async {
  final prefs = await readGlobalPrefs(scope: scope);
  return prefs.hasDefaultEnvironment() ? prefs.defaultEnvironment : 'stable';
}

Future<void> setDefaultEnvName({required Scope scope, required String envName}) async {
  ensureValidEnvName(envName);
  await EnvTransaction.run(
    scope: scope,
    body: (tx) async {
      // Update global prefs
      final prefsFile = scope.read(globalPrefsJsonFileProvider);
      final prefsExisted = prefsFile.existsSync();
      String? oldPrefsContent;
      if (prefsExisted) {
        oldPrefsContent = prefsFile.readAsStringSync();
      }
      await tx.step(
        label: 'update global prefs',
        action: () async {
          await updateGlobalPrefs(
            scope: scope,
            fn: (prefs) {
              prefs.defaultEnvironment = envName;
            },
          );
        },
        rollback: () async {
          if (oldPrefsContent != null) {
            prefsFile.writeAsStringSync(oldPrefsContent);
          } else if (prefsFile.existsSync()) {
            prefsFile.deleteSync();
          }
        },
      );

      // Update default env symlink
      final oldDefaultName = await getDefaultEnvName(scope: scope);
      await tx.step(
        label: 'update default env symlink',
        action: () async {
          await updateDefaultEnvSymlink(scope: scope, name: envName);
        },
        rollback: () async {
          await updateDefaultEnvSymlink(scope: scope, name: oldDefaultName);
        },
      );
    },
  );
}

Future<void> updateDefaultEnvSymlink({required Scope scope, String? name}) async {
  final config = HavenConfig.of(scope);
  name ??= await getDefaultEnvName(scope: scope);
  final environment = config.getEnv(name);
  final link = config.defaultEnvLink;

  if (environment.exists) {
    final path = environment.envDir.path;
    if (!FileSystemEntity.isLinkSync(link.path)) {
      if (link.existsSync()) {
        link.deleteSync();
      }
      link.parent.createSync(recursive: true);
      await createLink(scope: scope, link: link, path: path);
    } else if (link.targetSync() != path) {
      link.updateSync(path);
    }
  } else if (FileSystemEntity.isLinkSync(link.path)) {
    link.deleteSync();
  }
}
