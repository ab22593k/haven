import 'dart:io';

import 'package:file/file.dart';
import 'package:pub_semver/pub_semver.dart';

import '../config/config.dart';
import '../process.dart';
import '../provider.dart';

/// Manages Windows SDK detection and version querying.
class WindowsSdkManager {
  WindowsSdkManager({
    required this.scope,
  });

  final Scope scope;
  late final config = PuroConfig.of(scope);
  late final fileSystem = config.fileSystem;

  /// The registry path for Windows 10 SDK installation details.
  static const String _windows10SdkRegistryPath =
      r'HKEY_LOCAL_MACHINE\SOFTWARE\Wow6432Node\Microsoft\Microsoft SDKs\Windows\v10.0';

  /// The registry key in _windows10SdkRegistryPath for the folder where the
  /// SDKs are installed.
  static const String _windows10SdkRegistryKey = 'InstallationFolder';

  /// Returns the highest installed Windows 10 SDK version, or null if none is
  /// found.
  ///
  /// For instance: 10.0.18362.0.
  String? getWindows10SDKVersion() {
    final String? sdkLocation = getWindows10SdkLocation();
    if (sdkLocation == null) {
      return null;
    }
    final Directory sdkIncludeDirectory =
        config.fileSystem.directory(sdkLocation).childDirectory('Include');
    if (!sdkIncludeDirectory.existsSync()) {
      return null;
    }
    // The directories in this folder are named by the SDK version.
    Version? highestVersion;
    for (final FileSystemEntity versionEntry in sdkIncludeDirectory.listSync()) {
      if (versionEntry.basename.startsWith('10.')) {
        // Version only handles 3 components; strip off the '10.' to leave three
        // components, since they all start with that.
        final Version? version = Version.parse(versionEntry.basename.substring(3));
        if (highestVersion == null || (version != null && version > highestVersion)) {
          highestVersion = version;
        }
      }
    }
    if (highestVersion == null) {
      return null;
    }
    return '10.$highestVersion';
  }

  /// Returns the installation location of the Windows 10 SDKs, or null if the
  /// registry doesn't contain that information.
  String? getWindows10SdkLocation() {
    try {
      final ProcessResult result = runProcessSync(scope, 'reg', <String>[
        'query',
        _windows10SdkRegistryPath,
        '/v',
        _windows10SdkRegistryKey,
      ]);
      if (result.exitCode == 0) {
        final RegExp pattern = RegExp(r'InstallationFolder\s+REG_SZ\s+(.+)');
        final RegExpMatch? match = pattern.firstMatch(result.stdout as String);
        if (match != null) {
          return match.group(1)!.trim();
        }
      }
    } on ArgumentError {
      // Thrown if reg somehow doesn't exist; ignore and return null below.
    } on ProcessException {
      // Ignored, return null below.
    }
    return null;
  }

  /// Returns the highest-numbered SDK version in [dir], which should be the
  /// Windows 10 SDK installation directory.
  ///
  /// Returns null if no Windows 10 SDKs are found.
  String? findHighestVersionInSdkDirectory(Directory dir) {
    // This contains subfolders that are named by the SDK version.
    final Directory includeDir = dir.childDirectory('Includes');
    if (!includeDir.existsSync()) {
      return null;
    }
    Version? highestVersion;
    for (final FileSystemEntity versionEntry in includeDir.listSync()) {
      if (!versionEntry.basename.startsWith('10.')) {
        continue;
      }
      // Version only handles 3 components; strip off the '10.' to leave three
      // components, since they all start with that.
      final Version? version = Version.parse(versionEntry.basename.substring(3));
      if (highestVersion == null || (version != null && version > highestVersion)) {
        highestVersion = version;
      }
    }
    // Re-add the leading '10.' that was removed for comparison.
    return highestVersion == null ? null : '10.$highestVersion';
  }
}
