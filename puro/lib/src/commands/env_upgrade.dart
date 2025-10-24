import '../command.dart';
import '../command_result.dart';
import '../config.dart';
import '../env/releases.dart';
import '../env/upgrade.dart';
import '../env/version.dart';
import '../logger.dart';

class EnvUpgradeCommand extends PuroCommand {
  EnvUpgradeCommand() {
    argParser.addOption(
      'channel',
      help:
          'The Flutter channel, in case multiple channels have builds with the same version number.',
      valueHelp: 'name',
    );
    argParser.addFlag(
      'force',
      help: 'Forcefully upgrade the framework, erasing any unstaged changes',
      negatable: false,
    );
  }

  String? _backupPath;

  @override
  void cleanup() {
    if (_backupPath != null) {
      // Restore from backup if possible
      // Note: This is simplified; in practice, might need to move back
      PuroLogger.of(scope)
          .w('Upgrade failed; manual recovery may be needed. Backup at $_backupPath');
    }
  }

  @override
  final name = 'upgrade';

  @override
  List<String> get aliases => ['downgrade'];

  @override
  String? get argumentUsage => '<name> [version]';

  @override
  final description =
      'Upgrades or downgrades an environment to a new version of Flutter';

  @override
  Future<EnvUpgradeResult> run() async {
    final config = PuroConfig.of(scope);
    final channel = argResults!['channel'] as String?;
    final force = argResults!['force'] as bool;
    final args = unwrapArguments(atLeast: 1, atMost: 2);
    var version = args.length > 1 ? args[1] : null;

    final environment = config.getEnv(args[0]);

    if (!environment.exists && args[0].toLowerCase() == 'puro') {
      throw CommandError(
        'Environment `$name` does not exist\n'
        'Did you mean to run `puro upgrade-puro`?',
      );
    }
    environment.ensureExists();

    if (version == null && channel == null) {
      final prefs = await environment.readPrefs(scope: scope);
      if (prefs.hasDesiredVersion()) {
        final versionModel = prefs.desiredVersion;
        if (versionModel.hasBranch()) {
          version = prefs.desiredVersion.branch;
        }
      }
    }

    if (version == null && channel == null) {
      if (pseudoEnvironmentNames.contains(environment.name)) {
        version = environment.name;
      } else {
        throw CommandError(
          'No version provided and environment `${environment.name}` is not on a branch',
        );
      }
    }

    final toVersion = await FlutterVersion.query(
      scope: scope,
      version: version,
      channel: channel,
    );

    return withErrorRecovery(() async {
      return upgradeEnvironment(
        scope: scope,
        environment: environment,
        toVersion: toVersion,
        force: force,
      );
    });
  }
}
