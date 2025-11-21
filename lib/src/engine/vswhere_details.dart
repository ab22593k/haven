/// The details of a Visual Studio installation according to vswhere.
///
/// Mostly borrowed from https://github.com/flutter/flutter/blob/master/packages/flutter_tools/lib/src/windows/visual_studio.dart
class VswhereDetails {
  const VswhereDetails({
    required this.meetsRequirements,
    required this.installationPath,
    required this.displayName,
    required this.fullVersion,
    required this.isComplete,
    required this.isLaunchable,
    required this.isRebootRequired,
    required this.isPrerelease,
    required this.catalogDisplayVersion,
  });

  /// Create a `VswhereDetails` from the JSON output of vswhere.exe.
  factory VswhereDetails.fromJson(
    bool meetsRequirements,
    Map<String, dynamic> details,
  ) {
    final Map<String, dynamic>? catalog = details['catalog'] as Map<String, dynamic>?;

    return VswhereDetails(
      meetsRequirements: meetsRequirements,
      isComplete: details['isComplete'] as bool?,
      isLaunchable: details['isLaunchable'] as bool?,
      isRebootRequired: details['isRebootRequired'] as bool?,
      isPrerelease: details['isPrerelease'] as bool?,
      // Below are strings that must be well-formed without replacement characters.
      installationPath: _validateString(details['installationPath'] as String?),
      fullVersion: _validateString(details['installationVersion'] as String?),
      // Below are strings that are used only for display purposes and are allowed to
      // contain replacement characters.
      displayName: details['displayName'] as String?,
      catalogDisplayVersion: catalog == null
          ? null
          : catalog['productDisplayVersion'] as String?,
    );
  }

  /// Verify JSON strings from vswhere.exe output are valid.
  ///
  /// The output of vswhere.exe is known to output replacement characters.
  /// Use this to ensure values that must be well-formed are valid. Strings that
  /// are only used for display purposes should skip this check.
  /// See: https://github.com/flutter/flutter/issues/102451
  static String? _validateString(String? value) {
    if (value != null && value.contains('\u{FFFD}')) {
      throw AssertionError(
        'Bad UTF-8 encoding (U+FFFD; REPLACEMENT CHARACTER) found in string: $value.',
      );
    }

    return value;
  }

  /// Whether the installation satisfies the required workloads and minimum version.
  final bool meetsRequirements;

  /// The root directory of the Visual Studio installation.
  final String? installationPath;

  /// The user-friendly name of the installation.
  final String? displayName;

  /// The complete version.
  final String? fullVersion;

  /// Keys for the status of the installation.
  final bool? isComplete;
  final bool? isLaunchable;
  final bool? isRebootRequired;

  /// The key for a pre-release version.
  final bool? isPrerelease;

  /// The user-friendly version.
  final String? catalogDisplayVersion;

  /// Checks if the Visual Studio installation can be used by Flutter.
  ///
  /// Returns false if the installation has issues the user must resolve.
  /// This may return true even if required information is missing as older
  /// versions of Visual Studio might not include them.
  bool get isUsable {
    if (!meetsRequirements) {
      return false;
    }

    if (!(isComplete ?? true)) {
      return false;
    }

    if (!(isLaunchable ?? true)) {
      return false;
    }

    if (isRebootRequired ?? false) {
      return false;
    }

    return true;
  }
}
