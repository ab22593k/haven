import 'dart:io';

import '../config/config.dart';
import '../provider.dart';
import 'version.dart';

/// Service for handling file system operations related to environment creation.
class FileSystemService {
  const FileSystemService();

  /// Creates the environment directory.
  Future<void> createEnvironmentDirectory(Directory envDir) async {
    await envDir.create(recursive: true);
  }

  /// Prepares the rollback for prefs update and returns the action and rollback.
  Future<({Future<void> Function() action, Future<void> Function() rollback})>
  preparePrefsUpdate({
    required Scope scope,
    required EnvConfig environment,
    FlutterVersion? flutterVersion,
  }) async {
    final prefsFile = environment.prefsJsonFile;
    final prefsExisted = await prefsFile.exists();
    String? oldPrefsContent;
    if (prefsExisted) {
      oldPrefsContent = await prefsFile.readAsString();
    }

    final action = () async {
      await environment.updatePrefs(
        scope: scope,
        fn: (prefs) {
          prefs.clear();
          if (flutterVersion != null) {
            prefs.desiredVersion = flutterVersion.toModel();
          }
        },
      );
    };

    final rollback = () async {
      if (oldPrefsContent != null) {
        await prefsFile.writeAsString(oldPrefsContent);
      } else if (await prefsFile.exists()) {
        await prefsFile.delete();
      }
    };

    return (action: action, rollback: rollback);
  }
}
