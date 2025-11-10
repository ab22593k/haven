import 'dart:io';

import '../logger.dart';
import '../provider.dart';

/// A transactional framework for environment operations that supports rollback.
///
/// Operations are executed in sequence. If any step fails, registered rollbacks
/// are executed in reverse order to restore the system to a consistent state.
///
/// ## Transactional Guarantees
/// - **Scope**: Each environment operation (create/upgrade/rm) is atomic per environment.
///   No cross-environment or cross-command atomicity.
/// - **Success**: Environment is in a fully consistent, usable state.
/// - **Failure**: All registered rollbacks are attempted in reverse order.
///   - Resulting state is either fully rolled back or left in clearly recoverable locations (e.g., .puro-trash).
///   - Original error is preserved and rethrown; rollback failures are logged but don't mask it.
/// - **Non-goals**: Does not protect against concurrent manual edits or system-level races beyond existing locks.
///
/// ## Usage Guidelines
/// - Rollbacks must be idempotent and safe to run multiple times.
/// - Rollback failures are logged but don't prevent other rollbacks.
/// - Every side-effecting step must either be last or have a compensating rollback.
/// - For env operations: any create/move/modify of files/directories/git/config must register rollback.
class EnvTransaction {
  final PuroLogger logger;
  final List<Future<void> Function()> _rollbacks = [];
  bool _completed = false;

  EnvTransaction(this.logger);

  /// Runs a transactional body. If the body throws, rollbacks are executed.
  static Future<T> run<T>({
    required Scope scope,
    required Future<T> Function(EnvTransaction tx) body,
  }) async {
    final tx = EnvTransaction(PuroLogger.of(scope));
    tx.logger.v('Starting transaction');
    try {
      final result = await body(tx);
      tx._completed = true;
      tx.logger.v('Transaction completed successfully');
      return result;
    } catch (e) {
      tx.logger.w('Transaction failed: $e');
      await tx._rollbackAll();
      rethrow;
    }
  }

  /// Executes a step with an optional rollback action.
  Future<void> step({
    required String label,
    required Future<void> Function() action,
    Future<void> Function()? rollback,
  }) async {
    if (_completed) {
      throw StateError('Transaction already completed');
    }
    logger.d('Executing step: $label');
    try {
      await action();
      logger.d('Step "$label" completed');
      if (rollback != null) {
        _rollbacks.add(rollback);
        logger.d('Registered rollback for step: $label');
      }
    } catch (e) {
      logger.w('Step "$label" failed: $e');
      rethrow;
    }
  }

  /// Manually registers a rollback action.
  void addRollback(Future<void> Function() rollback) {
    if (_completed) {
      throw StateError('Transaction already completed');
    }
    _rollbacks.add(rollback);
  }

  /// Executes all rollbacks in reverse order.
  /// Rollbacks are run even if some fail; failures are logged but don't stop others.
  Future<void> _rollbackAll() async {
    if (_rollbacks.isEmpty) return;
    logger.v('Rolling back ${_rollbacks.length} steps');
    for (final rollback in _rollbacks.reversed) {
      try {
        await rollback();
      } catch (e) {
        logger.w('Rollback failed: $e');
      }
    }
  }

  // Helper: Create directory with rollback.
  Future<void> createDir(Directory dir) async {
    final existed = dir.existsSync();
    await step(
      label: 'create directory ${dir.path}',
      action: () => dir.create(recursive: true),
      rollback: existed ? null : () async => dir.deleteSync(recursive: true),
    );
  }

  // Helper: Write file with backup.
  Future<void> writeFile(File file, String contents) async {
    String? backup;
    if (file.existsSync()) {
      backup = file.readAsStringSync();
    }
    await step(
      label: 'write file ${file.path}',
      action: () => file.writeAsString(contents),
      rollback: backup != null
          ? () async => file.writeAsString(backup!)
          : () async => file.deleteSync(),
    );
  }

  // Helper: Move directory to trash for safe deletion.
  Future<Directory> moveToTrash(Directory dir) async {
    final trashDir = Directory('${dir.parent.path}/.puro-trash');
    await trashDir.create(recursive: true);
    final uniqueName = '${dir.basename}_${DateTime.now().millisecondsSinceEpoch}';
    final trashPath = '${trashDir.path}/$uniqueName';
    final trash = Directory(trashPath);
    await step(
      label: 'move to trash ${dir.path} -> ${trash.path}',
      action: () => dir.rename(trashPath),
      rollback: () => trash.rename(dir.path),
    );
    return trash;
  }

  // Helper: Replace path atomically (e.g., symlink swap).
  Future<void> replacePathAtomically({
    required FileSystemEntity current,
    required FileSystemEntity next,
  }) async {
    final tempPath = '${current.path}.tmp';
    final temp = FileSystemEntity.typeSync(current.path) == FileSystemEntityType.link
        ? Link(tempPath)
        : Directory(tempPath);
    await step(
      label: 'swap paths ${current.path} <-> ${next.path}',
      action: () async {
        await next.rename(tempPath);
        await current.rename(next.path);
        await temp.rename(current.path);
      },
      rollback: () async {
        await current.rename(tempPath);
        await next.rename(current.path);
        await temp.rename(next.path);
      },
    );
  }
}

// Extension for Directory to get basename.
extension DirectoryExt on Directory {
  String get basename => path.split(Platform.pathSeparator).last;
}
