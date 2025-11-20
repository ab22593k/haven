import 'dart:convert';
import 'dart:io';

import '../config/config.dart';
import '../logger.dart';
import '../process.dart';
import '../provider.dart';
import 'vswhere_details.dart';

/// Manages vswhere.exe queries for Visual Studio detection.
class VswhereManager {
  VswhereManager({
    required this.scope,
  });

  final Scope scope;
  late final config = HavenConfig.of(scope);
  late final log = HVLogger.of(scope);
  late final fileSystem = config.fileSystem;

  /// Matches the description property from the vswhere.exe JSON output.
  final RegExp _vswhereDescriptionProperty =
      RegExp(r'\s*"description"\s*:\s*".*"\s*,?');

  /// The minimum supported major version.
  static const int _minimumSupportedVersion = 16; // '16' is VS 2019.

  /// vswhere argument to specify the minimum version.
  static const String _vswhereMinVersionArgument = '-version';

  /// vswhere argument to allow prerelease versions.
  static const String _vswherePrereleaseArgument = '-prerelease';

  /// Workload ID for use with vswhere requirements.
  ///
  /// Workload ID is different between Visual Studio IDE and Build Tools.
  /// See https://docs.microsoft.com/en-us/visualstudio/install/workload-and-component-ids
  static const List<String> _requiredWorkloads = <String>[
    'Microsoft.VisualStudio.Workload.NativeDesktop',
    'Microsoft.VisualStudio.Workload.VCTools',
  ];

  /// Components for use with vswhere requirements.
  ///
  /// Maps from component IDs to description in the installer UI.
  /// See https://docs.microsoft.com/en-us/visualstudio/install/workload-and-component-ids
  Map<String, String> requiredComponents([int? majorVersion]) {
    // The description of the C++ toolchain required by the template. The
    // component name is significantly different in different versions.
    // When a new major version of VS is supported, its toolchain description
    // should be added below. It should also be made the default, so that when
    // there is no installation, the message shows the string that will be
    // relevant for the most likely fresh install case).
    String cppToolchainDescription;
    switch (majorVersion ?? _minimumSupportedVersion) {
      case 16:
      default:
        cppToolchainDescription = 'MSVC v142 - VS 2019 C++ x64/x86 build tools';
    }
    // The 'Microsoft.VisualStudio.Component.VC.Tools.x86.x64' ID is assigned to the latest
    // release of the toolchain, and there can be minor updates within a given version of
    // Visual Studio. Since it changes over time, listing a precise version would become
    // wrong after each VC++ toolchain update, so just instruct people to install the
    // latest version.
    cppToolchainDescription +=
        '\n   - If there are multiple build tool versions available, install the latest';
    // Things which are required by the workload (e.g., MSBuild) don't need to
    // be included here.
    return <String, String>{
      // The C++ toolchain required by the template.
      'Microsoft.VisualStudio.Component.VC.Tools.x86.x64': cppToolchainDescription,
      // CMake
      'Microsoft.VisualStudio.Component.VC.CMake.Project':
          'C++ CMake tools for Windows',
    };
  }

  /// The path to vswhere.exe.
  ///
  /// vswhere should be installed for VS 2017 Update 2 and later; if it's not
  /// present then there isn't a new enough installation of VS. This path is
  /// not user-controllable, unlike the install location of Visual Studio
  /// itself.
  String get _vswherePath {
    const String programFilesEnv = 'PROGRAMFILES(X86)';
    if (!Platform.environment.containsKey(programFilesEnv)) {
      throw AssertionError(
        '%$programFilesEnv% environment variable not found.',
      );
    }
    return fileSystem.path.join(
      Platform.environment[programFilesEnv]!,
      'Microsoft Visual Studio',
      'Installer',
      'vswhere.exe',
    );
  }

  /// Returns the details of the newest version of Visual Studio.
  ///
  /// If [validateRequirements] is set, the search will be limited to versions
  /// that have all of the required workloads and components.
  VswhereDetails? _visualStudioDetails({
    bool validateRequirements = false,
    List<String>? additionalArguments,
    String? requiredWorkload,
  }) {
    final List<String> requirementArguments = validateRequirements
        ? <String>[
            if (requiredWorkload != null) ...<String>[
              '-requires',
              requiredWorkload,
            ],
            ...requiredComponents(_minimumSupportedVersion).keys,
          ]
        : <String>[];
    try {
      final defaultArguments = <String>[
        '-format',
        'json',
        '-products',
        '*',
        '-utf8',
        '-latest',
      ];

      final whereResult = runProcessSync(
        scope,
        _vswherePath,
        <String>[
          ...defaultArguments,
          ...?additionalArguments,
          ...requirementArguments,
        ],
        stdoutEncoding: const Utf8Codec(allowMalformed: true),
      );

      if (whereResult.exitCode == 0) {
        final List<Map<String, dynamic>>? installations =
            _tryDecodeVswhereJson(whereResult.stdout as String);
        if (installations != null && installations.isNotEmpty) {
          return VswhereDetails.fromJson(validateRequirements, installations[0]);
        }
      }
    } on ArgumentError {
      // Thrown if vswhere doesn't exist; ignore and return null below.
    } on ProcessException {
      // Ignored, return null below.
    }
    return null;
  }

  List<Map<String, dynamic>>? _tryDecodeVswhereJson(String vswhereJson) {
    List<dynamic>? result;
    FormatException? originalError;
    try {
      // Some versions of vswhere.exe are known to encode their output incorrectly,
      // resulting in invalid JSON in the 'description' property when interpreted
      // as UTF-8. First, try to decode without any pre-processing.
      try {
        result = json.decode(vswhereJson) as List<dynamic>;
      } on FormatException catch (error) {
        // If that fails, remove the 'description' property and try again.
        // See: https://github.com/flutter/flutter/issues/106601
        vswhereJson = vswhereJson.replaceFirst(_vswhereDescriptionProperty, '');

        log.v(
          'Failed to decode vswhere.exe JSON output. $error'
          'Retrying after removing the unused description property:\n$vswhereJson',
        );

        originalError = error;
        result = json.decode(vswhereJson) as List<dynamic>;
      }
    } on FormatException {
      // Removing the description property didn't help.
      // Report the original decoding error on the unprocessed JSON.
      log.w(
        'Warning: Unexpected vswhere.exe JSON output. $originalError'
        'To see the full JSON, run flutter doctor -vv.',
      );
      return null;
    }

    return result.cast<Map<String, dynamic>>();
  }

  /// Returns the details of the best available version of Visual Studio.
  ///
  /// If there's a version that has all the required components, that
  /// will be returned, otherwise returns the latest installed version regardless
  /// of components and version, or null if no such installation is found.
  VswhereDetails? getBestVisualStudioDetails() {
    // First, attempt to find the latest version of Visual Studio that satisfies
    // both the minimum supported version and the required workloads.
    // Check in the order of stable VS, stable BT, pre-release VS, pre-release BT.
    final List<String> minimumVersionArguments = <String>[
      _vswhereMinVersionArgument,
      _minimumSupportedVersion.toString(),
    ];
    for (final bool checkForPrerelease in <bool>[false, true]) {
      for (final String requiredWorkload in _requiredWorkloads) {
        final VswhereDetails? result = _visualStudioDetails(
            validateRequirements: true,
            additionalArguments: checkForPrerelease
                ? <String>[...minimumVersionArguments, _vswherePrereleaseArgument]
                : minimumVersionArguments,
            requiredWorkload: requiredWorkload);

        if (result != null) {
          return result;
        }
      }
    }

    // An installation that satisfies requirements could not be found.
    // Fallback to the latest Visual Studio installation.
    return _visualStudioDetails(
        additionalArguments: <String>[_vswherePrereleaseArgument, '-all']);
  }
}
