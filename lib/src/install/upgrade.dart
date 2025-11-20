import 'dart:io';

import '../config/config.dart';
import '../downloader.dart';
import '../extensions.dart';
import '../http.dart';
import '../logger.dart';
import '../process.dart';
import '../provider.dart';
import '../terminal.dart';

Future<int> upgradeHaven({
  required Scope scope,
  required String targetVersion,
  required bool? path,
}) async {
  final config = HavenConfig.of(scope);
  final terminal = Terminal.of(scope);
  final log = HVLogger.of(scope);
  final buildTarget = config.buildTarget;
  final tempFile = config.havenExecutableTempFile;

  tempFile.parent.createSync(recursive: true);
  await downloadFile(
    scope: scope,
    url: config.havenBuildsUrl.append(
      path: '$targetVersion/'
          '${buildTarget.name}/'
          '${buildTarget.executableName}',
    ),
    file: tempFile,
    description: 'Downloading haven $targetVersion',
  );
  if (!Platform.isWindows) {
    await runProcess(scope, 'chmod', ['+x', '--', tempFile.path]);
  }
  config.havenExecutableFile.deleteOrRenameSync();
  tempFile.renameSync(config.havenExecutableFile.path);

  terminal.flushStatus();
  final installProcess = await startProcess(
    scope,
    config.havenExecutableFile.path,
    [
      if (terminal.enableColor) '--color',
      if (terminal.enableStatus) '--progress',
      '--log-level=${log.level?.index ?? 0}',
      'install-haven',
      if (path != null)
        if (path) '--path' else '--no-path',
    ],
  );
  final stdoutFuture = installProcess.stdout.listen(stdout.add).asFuture<void>();
  await installProcess.stderr.listen(stderr.add).asFuture<void>();
  await stdoutFuture;
  return installProcess.exitCode;
}
