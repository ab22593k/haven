import '../command_result.dart';
import '../config/config.dart';
import '../git.dart';
import '../logger.dart';
import '../proto/haven.pb.dart';
import '../provider.dart';
import 'env_shims.dart';
import 'flutter_tool.dart';
import 'git_operations_service.dart';
import 'transaction.dart';
import 'version.dart';

class EnvUpgradeResult extends MessageResult {
  EnvUpgradeResult({
    required this.environment,
    required this.from,
    required this.to,
    required this.forkRemoteUrl,
    this.switchedBranch = false,
    required this.toolInfo,
  }) : super(messages: [_buildMessage(environment, from, to, toolInfo)]);

  final EnvConfig environment;
  final FlutterVersion from;
  final FlutterVersion to;
  final String? forkRemoteUrl;
  final bool switchedBranch;
  final FlutterToolInfo toolInfo;

  bool get downgrade => from > to;

  static CommandMessage _buildMessage(
    EnvConfig environment,
    FlutterVersion from,
    FlutterVersion to,
    FlutterToolInfo toolInfo,
  ) {
    final downgrade = from > to;
    return CommandMessage.format(
      (format) => from.commit == to.commit
          ? toolInfo.didUpdateTool || toolInfo.didUpdateEngine
              ? 'Finished installation of $to in environment `${environment.name}`'
              : 'Environment `${environment.name}` is already up to date'
          : '${downgrade ? 'Downgraded' : 'Upgraded'} environment `${environment.name}`\n'
              '${from.toString(format)} => ${to.toString(format)}',
    );
  }

  @override
  CommandResultModel? get model => CommandResultModel(
        success: true,
        environmentUpgrade: EnvironmentUpgradeModel(
          name: environment.name,
          from: from.toModel(),
          to: to.toModel(),
        ),
      );
}

/// Upgrades an environment to a different version of flutter.
///
/// This operation is transactional: on failure, prefs and git state are restored
/// to pre-upgrade values. The environment is left at the old version or with
/// clear logs if rollback is incomplete.
Future<EnvUpgradeResult> upgradeEnvironment({
  required Scope scope,
  required EnvConfig environment,
  required FlutterVersion toVersion,
  bool force = false,
}) async {
  final log = HVLogger.of(scope);
  final git = GitClient.of(scope);
  environment.ensureExists();

  if (isValidVersion(environment.name) &&
      (toVersion.version == null || environment.name != '${toVersion.version}')) {
    throw CommandError(
      'Cannot upgrade environment ${environment.name} to a different version, '
      'run `haven use ${toVersion.name}` instead to switch your project',
    );
  }

  log.v('Upgrading environment in ${environment.envDir.path}');

  final repository = environment.flutterDir;
  final currentCommit = await git.getCurrentCommitHash(repository: repository);
  final branch = await git.getBranch(repository: repository);
  var prefs = await environment.readPrefs(scope: scope);
  final fromVersion = prefs.hasDesiredVersion()
      ? FlutterVersion.fromModel(prefs.desiredVersion)
      : await getEnvironmentFlutterVersion(
          scope: scope,
          environment: environment,
        );

  if (fromVersion == null) {
    throw CommandError("Couldn't find Flutter version, corrupt environment?");
  }

  // Capture git state for rollback
  final gitSnapshot = {
    'commit': currentCommit,
    'branch': branch,
  };

  return EnvTransaction.run(
      scope: scope,
      body: (tx) async {
        if (currentCommit != toVersion.commit ||
            (toVersion.branch != null && branch != toVersion.branch)) {
          // Update prefs
          final prefsFile = environment.prefsJsonFile;
          final prefsExisted = await prefsFile.exists();
          String? oldPrefsContent;
          if (prefsExisted) {
            oldPrefsContent = await prefsFile.readAsString();
          }
          await tx.step(
            label: 'update environment prefs',
            action: () async {
              prefs = await environment.updatePrefs(
                scope: scope,
                fn: (prefs) {
                  prefs.desiredVersion = toVersion.toModel();
                },
              );
            },
            rollback: () async {
              if (oldPrefsContent != null) {
                await prefsFile.writeAsString(oldPrefsContent);
              } else if (await prefsFile.exists()) {
                await prefsFile.delete();
              }
            },
          );

          if (prefs.hasForkRemoteUrl()) {
            if (branch == null) {
              throw CommandError(
                'HEAD is not attached to a branch, could not upgrade fork',
              );
            }
            if (await git.hasUncomittedChanges(repository: repository)) {
              throw CommandError(
                "Can't upgrade fork with uncomitted changes",
              );
            }
            await tx.step(
              label: 'upgrade fork via git operations',
              action: () async {
                await git.pull(repository: repository, all: true);
                final switchBranch =
                    toVersion.branch != null && branch != toVersion.branch;
                if (switchBranch) {
                  await git.checkout(repository: repository, ref: toVersion.branch!);
                }
                await git.merge(
                  repository: repository,
                  fromCommit: toVersion.commit,
                  fastForwardOnly: true,
                );
              },
              rollback: () async {
                // Restore to previous commit and branch
                await git.reset(
                    repository: repository, ref: gitSnapshot['commit']!, hard: true);
                if (gitSnapshot['branch'] != null) {
                  await git.checkout(
                      repository: repository, ref: gitSnapshot['branch']!);
                }
              },
            );

            final toolInfo = await setUpFlutterTool(
              scope: scope,
              environment: environment,
              environmentPrefs: prefs,
            );

            return EnvUpgradeResult(
              environment: environment,
              from: fromVersion,
              to: toVersion,
              forkRemoteUrl: prefs.forkRemoteUrl,
              switchedBranch: toVersion.branch != null && branch != toVersion.branch,
              toolInfo: toolInfo,
            );
          }

          await tx.step(
            label: 'clone flutter with shared refs',
            action: () async {
              await const GitOperationsService().cloneFlutterWithSharedRefs(
                scope: scope,
                repository: environment.flutterDir,
                flutterVersion: toVersion,
                environment: environment,
                forkRemoteUrl: prefs.hasForkRemoteUrl() ? prefs.forkRemoteUrl : null,
                force: force,
              );
            },
            rollback: () async {
              // Restore git state
              await git.reset(
                  repository: repository, ref: gitSnapshot['commit']!, hard: true);
              if (gitSnapshot['branch'] != null) {
                await git.checkout(repository: repository, ref: gitSnapshot['branch']!);
              }
            },
          );
        }

        // Replace flutter/dart with shims
        await tx.step(
          label: 'install environment shims',
          action: () async {
            await installEnvShims(
              scope: scope,
              environment: environment,
            );
          },
          rollback: () async {
            await uninstallEnvShims(scope: scope, environment: environment);
          },
        );

        final toolInfo = await setUpFlutterTool(
          scope: scope,
          environment: environment,
        );

        if (await environment.flutter.legacyVersionFile.exists()) {
          await tx.step(
            label: 'delete legacy version file',
            action: () async => await environment.flutter.legacyVersionFile.delete(),
            rollback: null, // No rollback needed for deletion
          );
        }

        return EnvUpgradeResult(
          environment: environment,
          from: fromVersion,
          to: toVersion,
          forkRemoteUrl: null,
          toolInfo: toolInfo,
        );
      });
}
