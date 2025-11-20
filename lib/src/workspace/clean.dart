import 'package:file/file.dart';
import 'package:path/path.dart' as path;

import '../config/config.dart';
import '../config/project.dart';
import '../logger.dart';
import '../provider.dart';
import 'common.dart';
import 'gitignore.dart';
import 'intellij.dart';
import 'vscode.dart';

/// Restores IDE settings back to their original.
Future<void> restoreIdeConfigs({
  required Scope scope,
  required Directory projectDir,
  required ProjectConfig projectConfig,
}) async {
  runOptional(
    scope,
    'restoring intellij config',
    () async {
      final ideConfig = await IntelliJConfig.load(
        scope: scope,
        projectDir: projectDir,
        projectConfig: projectConfig,
      );
      if (ideConfig.exists) {
        await restoreIdeConfig(
          scope: scope,
          ideConfig: ideConfig,
        );
      }
    },
  );

  runOptional(
    scope,
    'restoring vscode config',
    () async {
      final ideConfig = await VSCodeConfig.load(
        scope: scope,
        projectDir: projectDir,
        projectConfig: projectConfig,
      );
      if (ideConfig.exists) {
        await restoreIdeConfig(
          scope: scope,
          ideConfig: ideConfig,
        );
      }
    },
  );
}

Future<void> restoreIdeConfig({
  required Scope scope,
  required IdeConfig ideConfig,
}) async {
  final config = HavenConfig.of(scope);
  final log = HVLogger.of(scope);
  final envsDir = config.envsDir;

  bool isHaven(Directory? directory) {
    if (directory == null) return false;
    return path.isWithin(envsDir.path, directory.absolute.path);
  }

  // Only restore if the SDK path is an environment, this should be mostly
  // harmless either way.
  if (isHaven(ideConfig.flutterSdkDir) || isHaven(ideConfig.dartSdkDir)) {
    log.v('Restoring ${ideConfig.name}...');
    await ideConfig.restore(scope: scope);
  } else {
    log.v('${ideConfig.name} already restored');
  }
}

/// Restores the workspace to its state prior to `haven` usage,
/// reverting `.gitignore` and IDE configurations.
Future<void> cleanWorkspace({
  required Scope scope,
  Directory? projectDir,
  required ProjectConfig projectConfig,
}) async {
  final config = HavenConfig.of(scope);
  projectDir ??= config.project.ensureParentProjectDir();
  await runOptional(scope, 'restoring gitignore', () {
    return updateGitignore(
      scope: scope,
      projectDir: projectDir!,
      ignores: {},
    );
  });
  await runOptional(scope, 'restoring IDE configs', () {
    return restoreIdeConfigs(
      scope: scope,
      projectDir: projectDir!,
      projectConfig: projectConfig,
    );
  });
  if (config.project.dotfileForWriting.existsSync()) {
    config.project.dotfileForWriting.deleteSync();
  }
}
