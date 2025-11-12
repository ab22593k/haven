import 'dart:convert';
import 'dart:io';

import 'package:file/file.dart';

import '../../models.dart';
import '../command.dart';
import '../command_result.dart';
import '../config/config.dart';
import '../config/prefs.dart';
import '../env/env_shims.dart';
import '../logger.dart';
import '../provider.dart';
import '../version.dart';
import 'bin.dart';
import 'profile.dart';

/// Unified service for installation operations.
///
/// This service provides a clean API for all installation-related operations,
/// decoupling the business logic from CLI parsing and command handling.
class InstallCommandService {
  const InstallCommandService();

  /// Installs Puro with the specified options.
  ///
  /// Returns a tuple of (result, profilePath) where profilePath is used for cleanup.
  Future<(CommandResult, String?)> installPuro({
    required Scope scope,
    required PuroCommandRunner runner,
    required bool force,
    required bool promote,
    required String? profileOverride,
    required bool? updatePath,
    required Map<String, dynamic> contextOverrides,
  }) async {
    final puroVersion = await PuroVersion.of(scope);
    final config = PuroConfig.of(scope);
    final log = PuroLogger.of(scope);

    await ensurePuroInstalled(
      scope: scope,
      force: force,
      promote: promote,
    );

    final PuroGlobalPrefsModel prefs = await updateGlobalPrefs(
      scope: scope,
      fn: (prefs) {
        if (profileOverride != null) prefs.profileOverride = profileOverride;
        if (updatePath != null) prefs.enableProfileUpdate = updatePath;
        if (contextOverrides['pubCacheOverride'] != null) {
          prefs.pubCacheDir = contextOverrides['pubCacheOverride'] as String;
        }
        if (contextOverrides['flutterGitUrlOverride'] != null) {
          prefs.flutterGitUrl = contextOverrides['flutterGitUrlOverride'] as String;
        }
        if (contextOverrides['engineGitUrlOverride'] != null) {
          prefs.engineGitUrl = contextOverrides['engineGitUrlOverride'] as String;
        }
        if (contextOverrides['dartSdkGitUrlOverride'] != null) {
          prefs.dartSdkGitUrl = contextOverrides['dartSdkGitUrlOverride'] as String;
        }
        if (contextOverrides['versionsJsonUrlOverride'] != null) {
          prefs.releasesJsonUrl = contextOverrides['versionsJsonUrlOverride'] as String;
        }
        if (contextOverrides['flutterStorageBaseUrlOverride'] != null) {
          prefs.flutterStorageBaseUrl =
              contextOverrides['flutterStorageBaseUrlOverride'] as String;
        }
        if (contextOverrides['shouldInstallOverride'] != null) {
          prefs.shouldInstall = contextOverrides['shouldInstallOverride'] as bool;
        }
        if (contextOverrides['legacyPubCache'] != null) {
          prefs.legacyPubCache = contextOverrides['legacyPubCache'] as bool;
        }
      },
    );

    log.d(() =>
        'prefs: ${const JsonEncoder.withIndent('  ').convert(prefs.toProto3Json())}');

    // Update the PATH by default if this is a distribution install.
    String? profilePath;
    var updatedWindowsRegistry = false;
    final homeDir = config.homeDir.path;
    if ((updatePath ?? false) ||
        ((puroVersion.type == PuroInstallationType.distribution || promote) &&
                !prefs.hasEnableProfileUpdate() ||
            prefs.enableProfileUpdate)) {
      if (Platform.isLinux || Platform.isMacOS) {
        final profile = await installProfileEnv(
          scope: scope,
          profileOverride: prefs.hasProfileOverride() ? prefs.profileOverride : null,
        );
        profilePath = profile?.path;
        if (profilePath != null && profilePath.startsWith(homeDir)) {
          profilePath = '~' + profilePath.substring(homeDir.length);
        }
      } else if (Platform.isWindows) {
        updatedWindowsRegistry = await tryUpdateWindowsPath(
          scope: scope,
        );
      }
    }

    // Environment shims may have changed, update all of them to be safe
    config.envsDir.createSync(recursive: true);
    for (final envDir in config.envsDir.listSync().whereType<Directory>()) {
      if (envDir.basename == 'default') continue;
      final environment = config.getEnv(envDir.basename);
      if (!environment.flutterDir.childDirectory('.git').existsSync()) continue;
      await runOptional(
        scope,
        '`${environment.name}` post-upgrade',
        () async {
          await installEnvShims(scope: scope, environment: environment);
        },
      );
    }

    final externalMessage = await detectExternalFlutterInstallations(scope: scope);

    final updateMessage = await checkIfUpdateAvailable(
      scope: scope,
      runner: runner,
      alwaysNotify: true,
    );

    return (
      BasicMessageResult.list([
        if (externalMessage != null) externalMessage,
        if (updateMessage != null) updateMessage,
        if (profilePath != null)
          CommandMessage(
              'Updated PATH in $profilePath, reopen your terminal or `source $profilePath` for it to take effect'),
        if (updatedWindowsRegistry)
          CommandMessage(
            'Updated PATH in the Windows registry, reopen your terminal for it to take effect',
          ),
        CommandMessage(
          'Successfully installed Puro ${puroVersion.semver} to `${config.puroRoot.path}`',
        ),
      ]),
      profilePath
    );
  }
}
