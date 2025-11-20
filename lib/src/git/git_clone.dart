import 'package:file/file.dart';

import '../git.dart';
import '../progress.dart';

enum GitCloneStep {
  // We used to have 'remote: Counting objects' / 'remote: Compressing objects'
  // but git seems to print their progress all at once.
  receivingObjects('Receiving objects'),
  resolvingDeltas('Resolving deltas');

  const GitCloneStep(this.prefix);

  final String prefix;
}

extension GitClone on GitClient {
  /// https://git-scm.com/docs/git -clone
  Future<void> clone({
    required String remote,
    required Directory repository,
    bool shared = false,
    String? branch,
    Directory? reference,
    bool checkout = true,
    void Function(GitCloneStep step, double progress)? onProgress,
  }) async {
    if (onProgress != null) onProgress(GitCloneStep.values.first, 0);
    final cloneResult = await raw(
      [
        'clone',
        remote,
        if (branch != null) ...['--branch', branch],
        if (reference != null) ...['--reference', reference.path],
        if (!checkout) '--no-checkout',
        if (onProgress != null) '--progress',
        if (shared) '--shared',
        repository.path,
      ],
      onStderr: (line) {
        if (onProgress == null) return;
        if (line.endsWith(', done.')) return;
        for (final step in GitCloneStep.values) {
          final prefix = '${step.prefix}:';
          if (!line.startsWith(prefix)) continue;
          final percentIndex = line.indexOf('%', prefix.length);
          if (percentIndex < 0) {
            continue;
          }
          final percent = int.tryParse(line
              .substring(
                prefix.length,
                percentIndex,
              )
              .trimLeft());
          if (percent == null) continue;
          onProgress(step, percent / 100);
        }
      },
    );
    ensureSuccess(cloneResult);
  }

  Future<void> cloneWithProgress({
    required String remote,
    required Directory repository,
    bool shared = false,
    String? branch,
    Directory? reference,
    bool checkout = true,
    String? description,
  }) async {
    await ProgressNode.of(scope).wrap((scope, node) async {
      node.description = description ?? 'Cloning $remote';
      await clone(
        remote: remote,
        repository: repository,
        shared: shared,
        branch: branch,
        reference: reference,
        checkout: checkout,
        onProgress: terminal.enableStatus ? node.onCloneProgress : null,
      );
    });
  }
}
