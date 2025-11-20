import 'package:file/file.dart';

import '../config/config.dart';
import '../logger.dart';
import '../provider.dart';
import 'vswhere_details.dart';
import 'vswhere_manager.dart';
import 'windows_sdk_manager.dart';

/// Encapsulates information about the installed copy of Visual Studio, if any.
///
/// Mostly borrowed from https://github.com/flutter/flutter/blob/master/packages/flutter_tools/lib/src/windows/visual_studio.dart
class VisualStudio {
  VisualStudio({
    required this.scope,
  });

  final Scope scope;
  late final config = HavenConfig.of(scope);
  late final log = HVLogger.of(scope);
  late final fileSystem = config.fileSystem;
  late final vswhereManager = VswhereManager(scope: scope);
  late final windowsSdkManager = WindowsSdkManager(scope: scope);

  /// True if Visual Studio installation was found.
  ///
  /// Versions older than 2017 Update 2 won't be detected, so error messages to
  /// users should take into account that [false] may mean that the user may
  /// have an old version rather than no installation at all.
  bool get isInstalled => _bestVisualStudioDetails != null;

  bool get isAtLeastMinimumVersion {
    final int? installedMajorVersion = _majorVersion;
    return installedMajorVersion != null && installedMajorVersion >= 16; // VS 2019
  }

  /// True if there is a version of Visual Studio with all the components
  /// necessary to build the project.
  bool get hasNecessaryComponents => _bestVisualStudioDetails?.isUsable ?? false;

  /// The name of the Visual Studio install.
  ///
  /// For instance: "Visual Studio Community 2019". This should only be used for
  /// display purposes.
  String? get displayName => _bestVisualStudioDetails?.displayName;

  /// The user-friendly version number of the Visual Studio install.
  ///
  /// For instance: "15.4.0". This should only be used for display purposes.
  /// Logic based off the installation's version should use the `fullVersion`.
  String? get displayVersion => _bestVisualStudioDetails?.catalogDisplayVersion;

  /// The directory where Visual Studio is installed.
  String? get installLocation => _bestVisualStudioDetails?.installationPath;

  /// The full version of the Visual Studio install.
  ///
  /// For instance: "15.4.27004.2002".
  String? get fullVersion => _bestVisualStudioDetails?.fullVersion;

  // Properties that determine the status of the installation. There might be
  // Visual Studio versions that don't include them, so default to a "valid" value to
  // avoid false negatives.

  /// True if there is a complete installation of Visual Studio.
  ///
  /// False if installation is not found.
  bool get isComplete {
    if (_bestVisualStudioDetails == null) {
      return false;
    }
    return _bestVisualStudioDetails!.isComplete ?? true;
  }

  /// True if Visual Studio is launchable.
  ///
  /// False if installation is not found.
  bool get isLaunchable {
    if (_bestVisualStudioDetails == null) {
      return false;
    }
    return _bestVisualStudioDetails!.isLaunchable ?? true;
  }

  /// True if the Visual Studio installation is a pre-release version.
  bool get isPrerelease => _bestVisualStudioDetails?.isPrerelease ?? false;

  /// True if a reboot is required to complete the Visual Studio installation.
  bool get isRebootRequired => _bestVisualStudioDetails?.isRebootRequired ?? false;

  /// The name of the recommended Visual Studio installer workload.
  String get workloadDescription => 'Desktop development with C++';

  /// Returns the highest installed Windows 10 SDK version, or null if none is
  /// found.
  ///
  /// For instance: 10.0.18362.0.
  String? getWindows10SDKVersion() => windowsSdkManager.getWindows10SDKVersion();

  /// The names of the components within the workload that must be installed.
  ///
  /// The descriptions of some components differ from version to version. When
  /// a supported version is present, the descriptions used will be for that
  /// version.
  List<String> necessaryComponentDescriptions() {
    return vswhereManager.requiredComponents().values.toList();
  }

  /// Components for use with vswhere requirements.
  ///
  /// Maps from component IDs to description in the installer UI.
  /// See https://docs.microsoft.com/en-us/visualstudio/install/workload-and-component-ids
  Map<String, String> requiredComponents([int? majorVersion]) {
    return vswhereManager.requiredComponents(majorVersion);
  }

  /// The consumer-facing version name of the minimum supported version.
  ///
  /// E.g., for Visual Studio 2019 this returns "2019" rather than "16".
  String get minimumVersionDescription {
    return '2019';
  }

  /// The path to CMake, or null if no Visual Studio installation has
  /// the components necessary to build.
  String? get cmakePath {
    final VswhereDetails? details = _bestVisualStudioDetails;
    if (details == null || !details.isUsable || details.installationPath == null) {
      return null;
    }

    return fileSystem.path.joinAll(<String>[
      details.installationPath!,
      'Common7',
      'IDE',
      'CommonExtensions',
      'Microsoft',
      'CMake',
      'CMake',
      'bin',
      'cmake.exe',
    ]);
  }

  /// The generator string to pass to CMake to select this Visual Studio
  /// version.
  String? get cmakeGenerator {
    // From https://cmake.org/cmake/help/v3.22/manual/cmake-generators.7.html#visual-studio-generators
    switch (_majorVersion) {
      case 17:
        return 'Visual Studio 17 2022';
      case 16:
      default:
        return 'Visual Studio 16 2019';
    }
  }

  /// The major version of the Visual Studio install, as an integer.
  int? get _majorVersion =>
      fullVersion != null ? int.tryParse(fullVersion!.split('.')[0]) : null;

  /// Returns the details of the best available version of Visual Studio.
  ///
  /// If there's a version that has all the required components, that
  /// will be returned, otherwise returns the latest installed version regardless
  /// of components and version, or null if no such installation is found.
  late final VswhereDetails? _bestVisualStudioDetails =
      vswhereManager.getBestVisualStudioDetails();

  /// Returns the installation location of the Windows 10 SDKs, or null if the
  /// registry doesn't contain that information.
  String? getWindows10SdkLocation() => windowsSdkManager.getWindows10SdkLocation();

  /// Returns the highest-numbered SDK version in [dir], which should be the
  /// Windows 10 SDK installation directory.
  ///
  /// Returns null if no Windows 10 SDKs are found.
  String? findHighestVersionInSdkDirectory(Directory dir) =>
      windowsSdkManager.findHighestVersionInSdkDirectory(dir);
}
