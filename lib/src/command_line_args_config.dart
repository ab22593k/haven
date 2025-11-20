class CommandLineArgsConfig {
  CommandLineArgsConfig({
    required this.gitExecutable,
    required this.workingDir,
    required this.projectDir,
    required this.pubCache,
    required this.legacyPubCache,
    required this.flutterGitUrl,
    required this.engineGitUrl,
    required this.dartSdkGitUrl,
    required this.releasesJsonUrl,
    required this.flutterStorageBaseUrl,
    required this.environmentOverride,
    required this.shouldInstall,
    required this.shouldSkipCacheSync,
  });

  final String? gitExecutable;
  final String? workingDir;
  final String? projectDir;
  final String? pubCache;
  final bool? legacyPubCache;
  final String? flutterGitUrl;
  final String? engineGitUrl;
  final String? dartSdkGitUrl;
  final String? releasesJsonUrl;
  final String? flutterStorageBaseUrl;
  final String? environmentOverride;
  final bool? shouldInstall;
  final bool? shouldSkipCacheSync;
}
