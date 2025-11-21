import 'dart:io';

import 'package:pub_semver/pub_semver.dart';

import '../command.dart';
import '../command_result.dart';
import '../config/config.dart';
import '../http.dart';
import '../install/upgrade.dart';
import '../process.dart';
import '../terminal.dart';
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
    final force = argResults!['force'] as bool;
    final http = scope.read(clientProvider);
    final config = HavenConfig.of(scope);
    final havenVersion = await HavenVersion.of(scope);
    final currentVersion = havenVersion.semver;
    var targetVersionString = unwrapSingleOptionalArgument();

    if (havenVersion.type == HavenInstallationType.pub) {
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
    } else if (havenVersion.type != HavenInstallationType.distribution && !force) {
      return BasicMessageResult(
        "Can't upgrade: ${havenVersion.type.description}",
        success: false,
      );
    }

    if (targetVersionString == 'master') {
      final exitCode = await upgradeHaven(
        scope: scope,
        targetVersion: 'master',
        path: argResults!.wasParsed('path') ? argResults!['path'] as bool : null,
      );
      await runner.exitHaven(exitCode);
    }

    final Version targetVersion;
    if (targetVersionString == null) {
      final latestVersionResponse = await http.get(
        config.havenBuildsUrl.append(path: 'latest'),
      );
      HttpException.ensureSuccess(latestVersionResponse);
      targetVersionString = latestVersionResponse.body.trim();
      targetVersion = Version.parse(targetVersionString);
      if (currentVersion == targetVersion && !force) {
        return BasicMessageResult('Haven is up to date with $targetVersion');
      } else if (currentVersion > targetVersion && !force) {
        return BasicMessageResult(
          'Haven is a newer version $currentVersion than the available $targetVersion',
          type: CompletionType.indeterminate,
        );
      }
    } else {
      targetVersion = Version.parse(targetVersionString);
      if (currentVersion == targetVersion && !force) {
        return BasicMessageResult('Haven is the desired version $targetVersion');
      }
    }

    final exitCode = await upgradeHaven(
      scope: scope,
      targetVersion: '$targetVersion',
      path: argResults!.wasParsed('path') ? argResults!['path'] as bool : null,
    );

    await runner.exitHaven(exitCode);
  }
}
