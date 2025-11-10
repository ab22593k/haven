import 'package:file/file.dart';

import '../git.dart';

extension GitOperations on GitClient {
  /// https://git-scm.com/docs/git-checkout
  Future<void> checkout({
    required Directory repository,
    String? ref,
    bool detach = false,
    bool track = false,
    bool force = false,
    String? newBranch,
  }) async {
    final result = await raw(
      [
        'checkout',
        if (detach) '--detach',
        if (track) '--track',
        if (force) '-f',
        if (newBranch != null) ...['-b', newBranch],
        if (ref != null) ref,
      ],
      directory: repository,
    );
    ensureSuccess(result);
  }

  /// https://git-scm.com/docs/git-reset
  Future<void> reset({
    required Directory repository,
    String? ref,
    bool soft = false,
    bool mixed = false,
    bool hard = false,
    bool merge = false,
    bool keep = false,
  }) async {
    final result = await raw(
      [
        'reset',
        if (soft) '--soft',
        if (mixed) '--mixed',
        if (hard) '--hard',
        if (merge) '--merge',
        if (keep) '--keep',
        if (ref != null) ref,
      ],
      directory: repository,
    );
    ensureSuccess(result);
  }

  /// https://git-scm.com/docs/git-reset
  Future<bool> tryReset({
    required Directory repository,
    String? ref,
    bool soft = false,
    bool mixed = false,
    bool hard = false,
    bool merge = false,
    bool keep = false,
  }) async {
    final result = await raw(
      [
        'reset',
        if (soft) '--soft',
        if (mixed) '--mixed',
        if (hard) '--hard',
        if (merge) '--merge',
        if (keep) '--keep',
        if (ref != null) ref,
      ],
      directory: repository,
    );
    return result.exitCode == 0;
  }

  /// https://git-scm.com/docs/git-pull
  Future<void> pull({
    required Directory repository,
    String? remote,
    bool all = false,
  }) async {
    final result = await raw(
      [
        'pull',
        if (remote != null) remote,
        if (all) '--all',
      ],
      directory: repository,
    );
    ensureSuccess(result);
  }

  /// https://git-scm.com/docs/git-fetch
  Future<void> fetch({
    required Directory repository,
    String remote = 'origin',
    String? ref,
    bool all = false,
    bool updateHeadOk = false,
  }) async {
    final result = await raw(
      [
        'fetch',
        if (all) '--all',
        if (updateHeadOk) '--update-head-ok',
        if (!all) remote,
        if (ref != null) ref,
      ],
      directory: repository,
    );
    ensureSuccess(result);
  }

  /// https://git-scm.com/docs/git-merge
  Future<void> merge({
    required Directory repository,
    required String fromCommit,
    bool? fastForward,
    bool fastForwardOnly = false,
  }) async {
    final result = await raw(
      [
        'merge',
        if (fastForward != null)
          if (fastForward) '--ff' else '--no-ff',
        if (fastForwardOnly) '--ff-only',
        fromCommit,
      ],
      directory: repository,
    );
    ensureSuccess(result);
  }
}
