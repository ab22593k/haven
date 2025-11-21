import 'dart:io';

import '../command_result.dart';
import '../config/config.dart';
import '../config/project.dart';
import '../process.dart';
import '../provider.dart';
import '../terminal.dart';

/// Environment deletion uses a "move-to-trash" strategy for safety:
/// - Env directory is moved to .haven-trash under the env root.
/// - If final deletion succeeds, trash is removed.
/// - If final deletion fails, rollback moves env back from trash.
/// - Trash locations are logged for manual cleanup if needed.
import 'transaction.dart';

Future<void> ensureNoProjectsUsingEnv({
  required Scope scope,
  required EnvConfig environment,
}) async {
  final config = HavenConfig.of(scope);
  final dotfiles = await getDotfilesUsingEnv(scope: scope, environment: environment);
  if (dotfiles.isNotEmpty) {
    throw CommandError.list([
      CommandMessage(
        'Environment `${environment.name}` is currently used by the following '
        'projects:\n${dotfiles.map((p) => '* ${config.shortenHome(p.parent.path)}').join('\n')}',
      ),
      CommandMessage('Pass `-f` to ignore this warning', type: CompletionType.info),
    ]);
  }
}

/// Deletes an environment.
///
/// This operation is transactional: on failure, the environment is either
/// fully restored or moved to .haven-trash for manual recovery.
/// No half-deleted environments are left in inconsistent states.
Future<void> deleteEnvironment({
  required Scope scope,
  required String name,
  required bool force,
}) async {
  final config = HavenConfig.of(scope);
  final env = config.getEnv(name);
  env.ensureExists();

  if (!force) {
    await ensureNoProjectsUsingEnv(scope: scope, environment: env);
  }

  await EnvTransaction.run(
    scope: scope,
    body: (tx) async {
      // Delete the lock file
      final lockExisted = env.updateLockFile.existsSync();
      await tx.step(
        label: 'delete update lock file',
        action: () async {
          if (lockExisted) {
            await env.updateLockFile.delete();
          }
        },
        rollback: lockExisted
            ? () async {
                if (!env.updateLockFile.existsSync()) {
                  await env.updateLockFile.create(recursive: true);
                }
              }
            : null,
      );

      // Move env dir to trash for safe deletion
      final trash = await tx.moveToTrash(env.envDir);

      // Attempt to delete the trash
      await tx.step(
        label: 'delete environment directory',
        action: () async {
          try {
            await trash.delete(recursive: true);
          } on FileSystemException {
            if (!await env.flutter.cache.dartSdk.dartExecutable.exists()) {
              rethrow;
            }

            // Try killing dart processes that might be preventing us from deleting the
            // environment.
            if (Platform.isWindows) {
              await runProcess(scope, 'wmic', [
                'process',
                'where',
                'path="${(await env.flutter.cache.dartSdk.dartExecutable.resolveSymbolicLinks()).replaceAll('\\', '\\\\')}"',
                'delete',
              ]);
            } else {
              final result = await runProcess(scope, 'pgrep', [
                '-f',
                env.flutter.cache.dartSdk.dartExecutable.path,
              ]);
              final pids = (result.stdout as String).trim().split(RegExp('\\s+'));
              await runProcess(scope, 'kill', ['-9', ...pids]);
            }

            // Wait a bit for the handles to be released.
            await Future.delayed(const Duration(seconds: 2));

            // Try deleting again.
            await trash.delete(recursive: true);
          }
        },
        rollback:
            null, // If delete fails, transaction rolls back, moving back from trash
      );
    },
  );
}
