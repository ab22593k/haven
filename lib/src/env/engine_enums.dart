import '../provider.dart';
import 'engine_platform_detector.dart';

enum EngineOS { windows, macOS, linux }

enum EngineArch { x64, arm64 }

enum EngineBuildTarget {
  windowsX64('dart-sdk-windows-x64.zip', EngineOS.windows, EngineArch.x64),
  linuxX64('dart-sdk-linux-x64.zip', EngineOS.linux, EngineArch.x64),
  linuxArm64('dart-sdk-linux-arm64.zip', EngineOS.linux, EngineArch.arm64),
  macosX64('dart-sdk-darwin-x64.zip', EngineOS.macOS, EngineArch.x64),
  macosArm64('dart-sdk-darwin-arm64.zip', EngineOS.macOS, EngineArch.arm64);

  const EngineBuildTarget(this.zipName, this.os, this.arch);

  final String zipName;
  final EngineOS os;
  final EngineArch arch;

  static EngineBuildTarget from(EngineOS os, EngineArch arch) {
    switch (os) {
      case EngineOS.windows:
        switch (arch) {
          case EngineArch.x64:
            return EngineBuildTarget.windowsX64;
          case EngineArch.arm64:
            break;
        }
        break;
      case EngineOS.macOS:
        switch (arch) {
          case EngineArch.x64:
            return EngineBuildTarget.macosX64;
          case EngineArch.arm64:
            return EngineBuildTarget.macosArm64;
        }
      case EngineOS.linux:
        switch (arch) {
          case EngineArch.x64:
            return EngineBuildTarget.linuxX64;
          case EngineArch.arm64:
            return EngineBuildTarget.linuxArm64;
        }
    }
    throw AssertionError('Unsupported build target: $os $arch');
  }

  static Future<EngineBuildTarget> query({required Scope scope}) async {
    return const EnginePlatformDetector().queryBuildTarget(scope: scope);
  }

  static final Provider<Future<EngineBuildTarget>> provider = Provider(
    (scope) => query(scope: scope),
  );
}
