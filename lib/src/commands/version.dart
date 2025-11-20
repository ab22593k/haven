import '../command.dart';
import '../command_result.dart';
import 'version_service.dart';

class VersionCommand extends HavenCommand {
  VersionCommand() {
    argParser.addFlag(
      'plain',
      negatable: false,
      help: 'Print just the version to stdout and exit',
    );
    argParser.addFlag(
      'release',
      negatable: false,
      hide: true,
    );
  }

  @override
  String get name => 'version';

  @override
  String get description => 'Prints version information';

  @override
  bool get allowUpdateCheck => false;

  @override
  Future<CommandResult> run() async {
    const service = VersionCommandService();
    final plain = argResults!['plain'] as bool;
    if (plain) {
      await service.printPlainVersion(
        scope: scope,
        runner: runner,
      );
      // This won't be reached as exitHaven terminates the program
    }
    return service.getVersionInfo(
      scope: scope,
      runner: runner,
    );
  }
}
