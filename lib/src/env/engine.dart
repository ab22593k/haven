import 'dart:io';

import 'package:pub_semver/pub_semver.dart';

import '../../models.dart';
import '../config/config.dart';
import '../provider.dart';
import 'engine_cache_manager.dart';
import 'engine_downloader.dart';
import 'engine_version_detector.dart';

/// Unzips [zipFile] into [destination].
Future<void> unzip({
  required Scope scope,
  required File zipFile,
  required Directory destination,
}) async {
  await const EngineDownloader().unzip(
    scope: scope,
    zipFile: zipFile,
    destination: destination,
  );
}

Future<bool> downloadSharedEngine({
  required Scope scope,
  required String engineCommit,
}) async {
  return const EngineDownloader().downloadSharedEngine(
    scope: scope,
    engineCommit: engineCommit,
  );
}

Future<Version> getDartSDKVersion({
  required Scope scope,
  required DartSdkConfig dartSdk,
}) async {
  return const EngineVersionDetector().getDartSDKVersion(
    scope: scope,
    dartSdk: dartSdk,
  );
}

Future<void> syncFlutterCache({
  required Scope scope,
  required EnvConfig environment,
  HavenEnvPrefsModel? environmentPrefs,
}) async {
  await const EngineCacheManager().syncFlutterCache(
    scope: scope,
    environment: environment,
    environmentPrefs: environmentPrefs,
  );
}

Future<void> trySyncFlutterCache({
  required Scope scope,
  required EnvConfig environment,
}) async {
  await const EngineCacheManager().trySyncFlutterCache(
    scope: scope,
    environment: environment,
  );
}
