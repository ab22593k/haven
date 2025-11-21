import 'dart:io';

import 'package:file/file.dart';

import '../command_result.dart';
import '../config/config.dart';
import '../git.dart';
import '../logger.dart';
import '../progress.dart';
import '../provider.dart';
import '../terminal.dart';
import 'env_shims.dart';
import 'version.dart';

/// Service for handling git operations related to environment creation.
class GitOperationsService {
  const GitOperationsService();

  /// Clones or fetches from a remote, putting it in a shared repository.
  Future<void> fetchOrCloneShared({
    required Scope scope,
    required Directory repository,
    required String remoteUrl,
  }) async {
    final git = GitClient.of(scope);
    if (await repository.exists()) {
      await ProgressNode.of(scope).wrap((scope, node) async {
        node.description = 'Fetching $remoteUrl';
        await git.fetch(repository: repository);
      });
    } else {
      await git.cloneWithProgress(
        remote: remoteUrl,
        repository: repository,
        shared: true,
        checkout: false,
      );
    }
  }

  /// Checks out Flutter using git objects from a shared repository.
  Future<void> cloneFlutterWithSharedRefs({
    required Scope scope,
    required Directory repository,
    required EnvConfig environment,
    FlutterVersion? flutterVersion,
    String? forkRemoteUrl,
    String? forkRef,
    bool force = false,
  }) async {
    final git = GitClient.of(scope);
    final config = HavenConfig.of(scope);
    final log = HVLogger.of(scope);

    log.v('Cloning flutter with shared refs');
    log.d('repository: ${repository.path}');
    log.d('flutterVersion: $flutterVersion');
    log.d('forkRemoteUrl: $flutterVersion');
    log.d('forkRef: $forkRef');

    if ((flutterVersion == null) == (forkRemoteUrl == null)) {
      throw AssertionError(
        'Exactly one of flutterVersion and forkRemoteUrl should be provided',
      );
    }

    final sharedRepository = config.sharedFlutterDir;

    // Set the remotes, git alternates, and unlink the cache.
    Future<void> initialize() async {
      final origin = forkRemoteUrl ?? config.flutterGitUrl;
      final upstream = forkRemoteUrl == null ? null : config.flutterGitUrl;

      final remotes = {
        if (upstream != null) 'upstream': GitRemoteUrls.single(upstream),
        'origin': GitRemoteUrls.single(origin),
      };

      if (!await repository.childDirectory('.git').exists()) {
        await repository.create(recursive: true);
        await git.init(repository: repository);
      }
      final alternatesFile = repository
          .childDirectory('.git')
          .childDirectory('objects')
          .childDirectory('info')
          .childFile('alternates');
      final sharedObjects = sharedRepository
          .childDirectory('.git')
          .childDirectory('objects');
      await alternatesFile.writeAsString('${sharedObjects.path}\n');
      await git.syncRemotes(repository: repository, remotes: remotes);

      // Delete the cache when we switch versions so the new version doesn't
      // accidentally corrupt the shared engine.
      final cacheDir = repository.childDirectory('bin').childDirectory('cache');
      if (await cacheDir.exists()) {
        log.d('Deleting ${cacheDir.path} from previous version');
        await cacheDir.delete(recursive: true);
      }
    }

    Future<void> guardCheckout(Future<void> Function() fn) async {
      // Uninstall shims so they don't interfere with merges (this technically
      // shouldn't happen with our attribute merge strategies, but w/e)
      await uninstallEnvShims(scope: scope, environment: environment);
      try {
        await fn();
      } on FileSystemException catch (exception, stackTrace) {
        throw CommandError.list([
          CommandMessage(
            'File system error during checkout. To overwrite local changes, try passing --force',
            type: CompletionType.info,
          ),
          CommandMessage('$exception\n$stackTrace'),
        ]);
      } on ProcessException catch (exception, stackTrace) {
        throw CommandError.list([
          CommandMessage(
            'Git process error during checkout. To overwrite local changes, try passing --force',
            type: CompletionType.info,
          ),
          CommandMessage('$exception\n$stackTrace'),
        ]);
      } catch (exception, stackTrace) {
        throw CommandError.list([
          CommandMessage(
            'To overwrite local changes, try passing --force',
            type: CompletionType.info,
          ),
          CommandMessage('$exception\n$stackTrace'),
        ]);
      } finally {
        await installEnvShims(scope: scope, environment: environment);
      }
    }

    // Cloning a fork is a little simpler, we don't need to reset the branch to
    // fit a specific flutter version
    if (forkRemoteUrl != null) {
      await fetchOrCloneShared(
        scope: scope,
        repository: sharedRepository,
        remoteUrl: config.flutterGitUrl,
      );

      await ProgressNode.of(scope).wrap((scope, node) async {
        node.description = 'Initializing repository';

        await initialize();

        node.description = 'Fetching $forkRef';

        await git.fetch(repository: repository);

        forkRef ??= await git.getDefaultBranch(repository: repository);

        node.description = 'Checking out $forkRef';

        await guardCheckout(() async {
          await git.checkout(repository: repository, ref: forkRef, force: force);
        });
      });

      return;
    }

    if (!await git.checkCommitExists(
      repository: config.sharedFlutterDir,
      commit: flutterVersion!.commit,
    )) {
      await fetchOrCloneShared(
        scope: scope,
        repository: sharedRepository,
        remoteUrl: config.flutterGitUrl,
      );
    }

    await ProgressNode.of(scope).wrap((scope, node) async {
      node.description = 'Initializing repository';

      await initialize();

      node.description = 'Checking out $flutterVersion';

      await git.fetch(repository: repository, all: true);

      final branch = flutterVersion.branch;
      if (branch != null) {
        // Unstage changes, excluded files may have been added by accident.
        await git.reset(repository: repository);

        final currentBranch = await git.getBranch(repository: repository);

        if (branch == currentBranch) {
          // Reset the current branches commit to the target commit, attempt to
          // merge uncomitted changes.
          if (force) {
            if (!await git.tryReset(
              repository: repository,
              ref: flutterVersion.commit,
              merge: true,
            )) {
              // We are forcefully upgrading, ditch uncommitted changes.
              await git.reset(
                repository: repository,
                ref: flutterVersion.commit,
                hard: true,
              );
            }
          } else {
            await guardCheckout(() async {
              await git.reset(
                repository: repository,
                ref: flutterVersion.commit,
                merge: true,
              );
            });
          }
        } else {
          // Delete the target branch if it exists (unless we are on a fork).
          if (await git.checkBranchExists(repository: repository, branch: branch) &&
              forkRemoteUrl == null) {
            await git.deleteBranch(repository: repository, branch: branch);
          }

          await guardCheckout(() async {
            // Reset branch to current commit, this allows flutter to correctly detect
            // its version and feature flags.
            await git.checkout(
              repository: repository,
              newBranch: branch,
              ref: flutterVersion.commit,
              force: force,
            );
          });
        }

        await git.branch(
          repository: repository,
          setUpstream: 'origin/$branch',
          branch: branch,
        );
      } else {
        await guardCheckout(() async {
          // Check out in a detached state, flutter will be unable to detect its
          // version.
          await git.checkout(
            repository: repository,
            ref: flutterVersion.commit,
            force: force,
          );
        });
      }
    });
  }
}
