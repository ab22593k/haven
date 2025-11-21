import 'dart:io';

import '../command_result.dart';
import '../process.dart';
import '../provider.dart';
import 'engine_enums.dart';

/// Detects the current platform's OS and architecture for engine builds.
class EnginePlatformDetector {
  const EnginePlatformDetector();

  /// Determines the current platform's OS.
  EngineOS detectOS() {
    if (Platform.isWindows) {
      return EngineOS.windows;
    } else if (Platform.isMacOS) {
      return EngineOS.macOS;
    } else if (Platform.isLinux) {
      return EngineOS.linux;
    } else {
      throw UnsupportedOSError();
    }
  }

  /// Determines the current platform's architecture.
  Future<EngineArch> detectArch({required Scope scope}) async {
    final os = detectOS();
    switch (os) {
      case EngineOS.windows:
        return EngineArch.x64;
      case EngineOS.macOS:
        final sysctlResult = await runProcess(scope, 'sysctl', [
          '-n',
          'hw.optional.arm64',
        ], runInShell: true);
        final stdout = (sysctlResult.stdout as String).trim();
        if (sysctlResult.exitCode != 0 || stdout == '0') {
          return EngineArch.x64;
        } else if (stdout == '1') {
          return EngineArch.arm64;
        } else {
          throw AssertionError('Unexpected result from sysctl: `$stdout`');
        }
      case EngineOS.linux:
        final unameResult = await runProcess(
          scope,
          'uname',
          ['-m'],
          runInShell: true,
          throwOnFailure: true,
        );
        final unameStdout = unameResult.stdout as String;
        if (const ['arm64', 'aarch64', 'armv8'].any(unameStdout.contains)) {
          return EngineArch.arm64;
        } else if (const ['x64', 'x86_64'].any(unameStdout.contains)) {
          return EngineArch.x64;
        } else {
          throw AssertionError('Unrecognized architecture: `$unameStdout`');
        }
    }
  }

  /// Queries the current build target for the platform.
  Future<EngineBuildTarget> queryBuildTarget({required Scope scope}) async {
    final os = detectOS();
    final arch = await detectArch(scope: scope);
    return EngineBuildTarget.from(os, arch);
  }
}
