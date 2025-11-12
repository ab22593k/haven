import '../command.dart';
import '../env/service.dart';
import '../env/upgrade.dart';

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
    const service = EnvService();
    final channel = argResults!['channel'] as String?;
    final force = argResults!['force'] as bool;
    final args = unwrapArguments(atLeast: 1, atMost: 2);
    final version = args.length > 1 ? args[1] : null;
    final envName = args[0];

    return withErrorRecovery(() async {
      return service.upgradeEnv(
        scope: scope,
        envName: envName,
        channel: channel,
        version: version,
        force: force,
      );
    });
  }
}
