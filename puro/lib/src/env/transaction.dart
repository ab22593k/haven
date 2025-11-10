import 'dart:io';

import '../logger.dart';
import '../provider.dart';

/// A transactional framework for environment operations that supports rollback.
///
/// Operations are executed in sequence. If any step fails, registered rollbacks
/// are executed in reverse order to restore the system to a consistent state.
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
    try {
      final result = await body(tx);
      tx._completed = true;
      return result;
    } catch (e) {
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
    try {
      await action();
      if (rollback != null) {
        _rollbacks.add(rollback);
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
  Future<void> _rollbackAll() async {
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