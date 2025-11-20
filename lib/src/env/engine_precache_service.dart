import 'dart:convert';

import '../config/config.dart';
import '../git.dart';
import '../http.dart';
import '../provider.dart';
import 'engine.dart';

/// Checks if a framework commit is a monorepo and has the engine in it.
Future<bool?> isCommitMonolithicEngine({
  required Scope scope,
  required String commit,
}) async {
  final config = HavenConfig.of(scope);
  final git = GitClient.of(scope);
  final http = scope.read(clientProvider);
  final sharedRepository = config.sharedFlutterDir;
  final result = await git.exists(
    repository: sharedRepository,
    path: 'engine/src/.gn',
    ref: commit,
  );
  if (result) return true;
  // 'exists' can return false if git show failed for some reason, so we also
  // check if the repository has a README.md to rule that out.
  if (await git.exists(
    repository: sharedRepository,
    path: 'README.md',
    ref: commit,
  )) {
    return false;
  }
  // Fall back to checking with HTTP
  final url = config.tryGetFlutterGitDownloadUrl(
    commit: commit,
    path: 'engine/src/.gn',
  );
  if (url == null) return null;
  final response = await http.head(url);
  if (response.statusCode == 200) return true;
  if (response.statusCode == 404) return false;
  HttpException.ensureSuccess(response);
  return null;
}

/// Attempts to get the engine version of a flutter commit. This is only used
/// for precaching the engine before cloning flutter. For an existing checkout
/// use [FlutterConfig.engineVersion] instead.
Future<String?> getEngineVersionOfCommit({
  required Scope scope,
  required String commit,
}) async {
  if (await isCommitMonolithicEngine(scope: scope, commit: commit) ?? false) {
    return commit;
  }

  final config = HavenConfig.of(scope);
  final git = GitClient.of(scope);
  final http = scope.read(clientProvider);
  final sharedRepository = config.sharedFlutterDir;
  final result = await git.tryCat(
    repository: sharedRepository,
    path: 'bin/internal/engine.version',
    ref: commit,
  );
  if (result != null) {
    return utf8.decode(result).trim();
  }
  final url = config.tryGetFlutterGitDownloadUrl(
    commit: commit,
    path: 'bin/internal/engine.version',
  );
  if (url == null) return null;
  final response = await http.get(url);
  HttpException.ensureSuccess(response);
  return response.body.trim();
}

/// Service for handling engine precaching.
class EnginePrecacheService {
  const EnginePrecacheService();

  /// Precaches the engine for the given commit.
  Future<void> precacheEngine({
    required Scope scope,
    required String commit,
  }) async {
    final engineVersion = await getEngineVersionOfCommit(
      scope: scope,
      commit: commit,
    );
    if (engineVersion == null) {
      return;
    }
    await downloadSharedEngine(
      scope: scope,
      engineCommit: engineVersion,
    );
  }
}
