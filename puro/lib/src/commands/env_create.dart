import '../command.dart';
import '../command_result.dart';
import '../config/config.dart';
import '../env/create.dart';
import '../env/default.dart';
import '../env/releases.dart';
import '../env/version.dart';
import '../install/bin.dart';
import '../logger.dart';

class EnvCreateCommand extends PuroCommand {
  EnvCreateCommand() {
    argParser.addOption(
      'channel',
      help:
          'The Flutter channel, in case multiple channels have builds with the same version number.',
      valueHelp: 'name',
    );
    argParser.addOption(
      'fork',
      help:
          'The origin to use when cloning the framework, puro will set the upstream automatically.',
      valueHelp: 'url',
    );
  }

  String? _createdEnvName;

  @override
  void cleanup() {
    if (_createdEnvName != null) {
      final config = PuroConfig.of(scope);
      final env = config.getEnv(_createdEnvName!);
      if (env.exists) {
        try {
          env.envDir.deleteSync(recursive: true);
        } catch (e) {
          // Log but don't throw in cleanup
          PuroLogger.of(scope).w('Failed to cleanup environment $_createdEnvName: $e');
        }
      }
    }
  }

  @override
  final name = 'create';

  @override
  String? get argumentUsage => '<name> [version]';

  @override
  final description = 'Sets up a new Flutter environment';

  @override
  Future<EnvCreateResult> run() async {
    final channel = argResults!['channel'] as String?;
    final fork = argResults!['fork'] as String?;
    final args = unwrapArguments(atLeast: 1, atMost: 2);
    final version = args.length > 1 ? args[1] : null;
    final envName = args.first.toLowerCase();
    ensureValidEnvName(envName);

    await ensurePuroInstalled(scope: scope);

    return withErrorRecovery(() async {
      _createdEnvName = envName;
      if (fork != null) {
        if (pseudoEnvironmentNames.contains(envName) || isValidVersion(envName)) {
          throw CommandError(
            'Cannot create fixed version `$envName` with a fork',
          );
        }
        return createEnvironment(
          scope: scope,
          envName: envName,
          forkRemoteUrl: fork,
          forkRef: version,
        );
      } else {
        return createEnvironment(
          scope: scope,
          envName: envName,
          flutterVersion: await FlutterVersion.query(
            scope: scope,
            version: version,
            channel: channel,
            defaultVersion: isPseudoEnvName(envName) ? envName : 'stable',
          ),
        );
      }
    });
  }
}
