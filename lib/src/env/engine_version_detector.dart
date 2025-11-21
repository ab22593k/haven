import 'package:pub_semver/pub_semver.dart';

import '../config/config.dart';
import '../process.dart';
import '../provider.dart';

/// Detects Dart SDK versions from installed engines.
class EngineVersionDetector {
  const EngineVersionDetector();

  static final _dartSdkRegex = RegExp(r'Dart SDK version: (\S+)');

  /// Gets the Dart SDK version from a given Dart SDK configuration.
  Future<Version> getDartSDKVersion({
    required Scope scope,
    required DartSdkConfig dartSdk,
  }) async {
    final result = await runProcess(scope, dartSdk.dartExecutable.path, [
      '--version',
    ], throwOnFailure: true);
    final match = EngineVersionDetector._dartSdkRegex.firstMatch(
      result.stdout as String,
    );
    if (match == null) {
      throw AssertionError('Failed to parse `${result.stdout}`');
    }
    return Version.parse(match.group(1)!);
  }
}
