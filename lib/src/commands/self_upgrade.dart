import 'dart:io';

import '../command.dart';
import '../command_result.dart';
import '../process.dart';
import '../version.dart';

class SelfUpgradeCommand extends HavenCommand {
  SelfUpgradeCommand() {
    argParser.addFlag(
      'force',
      hide: true,
      help: 'Installs a new haven executable even if it wont replace an existing one',
      negatable: false,
    );
    argParser.addFlag('path', help: 'Whether or not to update the PATH automatically');
  }

  @override
  final name = 'upgrade-haven';

  @override
  List<String> get aliases => ['update-haven'];

  @override
  String? get argumentUsage => '[version]';

  @override
  final description = 'Upgrades the haven tool to a new version';

  @override
  bool get allowUpdateCheck => false;

  @override
  Future<CommandResult> run() async {
    final havenVersion = await HavenVersion.of(scope);
    final currentVersion = havenVersion.semver;

    final result = await runProcess(scope, Platform.resolvedExecutable, [
      'pub',
      'global',
      'activate',
      'haven',
    ]);
    if (result.exitCode == 0) {
      final stdout = result.stdout as String;
      if (stdout.contains('already activated at newest available version')) {
        return BasicMessageResult('Haven is up to date with $currentVersion');
      } else {
        return BasicMessageResult('Upgraded haven to latest pub version');
      }
    } else {
      return BasicMessageResult(
        '`dart pub global activate haven` failed with exit code ${result.exitCode}\n${result.stderr}'
            .trim(),
        success: false,
      );
    }
  }
}
