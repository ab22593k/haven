import '../command.dart';
import '../command_result.dart';
import '../install/command.dart';
import '../logger.dart';

class PuroInstallCommand extends PuroCommand {
  PuroInstallCommand() {
    argParser.addFlag(
      'force',
      help: 'Overwrite an existing puro installation, if any',
      negatable: false,
    );
    argParser.addFlag(
      'promote',
      help: 'Promotes a standalone executable to a full installation',
      negatable: false,
    );
    argParser.addFlag(
      'path',
      help: 'Whether or not to update the PATH automatically',
    );
    argParser.addOption(
      'profile',
      help: 'Overrides the profile script puro appends to when updating the PATH',
    );
  }

  String? _updatedProfilePath;

  @override
  void cleanup() {
    if (_updatedProfilePath != null) {
      PuroLogger.of(scope).w(
          'Installation failed; profile at $_updatedProfilePath may need manual cleanup');
    }
  }

  @override
  final name = 'install-puro';

  @override
  bool get hidden => true;

  @override
  final description = 'Finishes installation of the puro tool';

  @override
  bool get allowUpdateCheck => false;

  @override
  Future<CommandResult> run() async {
    const service = InstallCommandService();

    final force = argResults!['force'] as bool;
    final promote = argResults!['promote'] as bool;
    final profileOverride = argResults!['profile'] as String?;
    final updatePath =
        argResults!.wasParsed('path') ? argResults!['path'] as bool : null;

    final contextOverrides = {
      'pubCacheOverride': runner.context.pubCacheOverride,
      'flutterGitUrlOverride': runner.context.flutterGitUrlOverride,
      'engineGitUrlOverride': runner.context.engineGitUrlOverride,
      'dartSdkGitUrlOverride': runner.context.dartSdkGitUrlOverride,
      'versionsJsonUrlOverride': runner.context.versionsJsonUrlOverride,
      'flutterStorageBaseUrlOverride': runner.context.flutterStorageBaseUrlOverride,
      'shouldInstallOverride': runner.context.shouldInstallOverride,
      'legacyPubCache': runner.context.legacyPubCache,
    };

    return withErrorRecovery(() async {
      final (result, profilePath) = await service.installPuro(
        scope: scope,
        runner: runner,
        force: force,
        promote: promote,
        profileOverride: profileOverride,
        updatePath: updatePath,
        contextOverrides: contextOverrides,
      );
      _updatedProfilePath = profilePath;
      return result;
    });
  }
}
