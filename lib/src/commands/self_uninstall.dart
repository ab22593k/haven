import 'dart:io';

import '../command.dart';
import '../command_result.dart';
import '../config/config.dart';
import '../config/prefs.dart';
import '../install/profile.dart';
import '../terminal.dart';
import '../version.dart';

class SelfUninstallCommand extends HavenCommand {
  SelfUninstallCommand() {
    argParser.addFlag(
      'force',
      help: 'Ignore the current installation method and attempt to uninstall anyway',
      negatable: false,
    );
    argParser.addOption(
      'profile',
      help: 'Overrides the profile script haven appends to when updating the PATH',
    );
  }

  @override
  final name = 'uninstall-haven';

  @override
  final description = 'Uninstalls haven from the system';

  @override
  bool get allowUpdateCheck => false;

  @override
  Future<CommandResult> run() async {
    final havenVersion = await HavenVersion.of(scope);
    final config = HavenConfig.of(scope);
    final force = argResults!['force'] as bool;

    if (havenVersion.type != HavenInstallationType.distribution && !force) {
      throw CommandError(
        'Can only uninstall haven when installed normally, use --force to ignore\n'
        '${havenVersion.type.description}',
      );
    }

    final prefs = await readGlobalPrefs(scope: scope);

    String? profilePath;
    var updatedWindowsRegistry = false;
    final homeDir = config.homeDir.path;
    if (Platform.isLinux || Platform.isMacOS) {
      final profile = await uninstallProfileEnv(
        scope: scope,
        profileOverride: prefs.hasProfileOverride() ? prefs.profileOverride : null,
      );
      profilePath = profile?.path.replaceAll(homeDir, '~');
    } else if (Platform.isWindows) {
      updatedWindowsRegistry = await tryCleanWindowsPath(scope: scope);
    }

    if (profilePath == null && !updatedWindowsRegistry) {
      throw CommandError('Could not find Haven in your PATH, is it still installed?');
    }

    return BasicMessageResult.list([
      if (profilePath != null)
        CommandMessage(
          'Removed Haven from PATH in $profilePath, reopen your terminal for it to take effect',
        ),
      if (updatedWindowsRegistry)
        CommandMessage(
          'Removed Haven from PATH in the Windows registry, reopen your terminal for it to take effect',
        ),
      CommandMessage.format(
        (format) => Platform.isWindows
            ? 'To delete environments and settings, delete \'${config.havenRoot.path}\''
            : 'To delete environments and settings, rm -r \'${config.havenRoot.path}\'',
        type: CompletionType.info,
      ),
    ]);
  }
}
