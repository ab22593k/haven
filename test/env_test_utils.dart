import 'package:file/file.dart';
import 'package:file/local.dart';
import 'package:haven/src/config/config.dart';
import 'package:haven/src/config/prefs.dart';
import 'package:haven/src/config/project.dart';
import 'package:haven/src/logger.dart';
import 'package:haven/src/progress.dart';
import 'package:haven/src/provider.dart';
import 'package:haven/src/terminal.dart';
import 'package:mockito/mockito.dart';

class MockHavenConfig extends Mock implements HavenConfig {
  final Map<String, MockEnvConfig> _envs = {};
  final LocalFileSystem _fs = const LocalFileSystem();
  late final Link _defaultEnvLink;
  late final Directory _envsDir;
  late final File _cachedReleasesJsonFile;

  MockHavenConfig() {
    _defaultEnvLink = _fs.link('${_fs.systemTempDirectory.path}/default_env_link');
    _envsDir = _fs.directory('${_fs.systemTempDirectory.path}/envs');
    _cachedReleasesJsonFile = _fs.file(
      '${_fs.systemTempDirectory.path}/cached_releases.json',
    );
  }

  void addEnv(String name, MockEnvConfig env) {
    _envs[name] = env;
  }

  @override
  EnvConfig getEnv(String name, {bool resolve = true}) {
    return _envs[name] ?? MockEnvConfig(name, false);
  }

  @override
  Link get defaultEnvLink => _defaultEnvLink;

  @override
  Directory get envsDir => _envsDir;

  @override
  File get cachedReleasesJsonFile => _cachedReleasesJsonFile;

  // For rename test
  void renameEnv(String oldName, String newName) {
    if (_envs.containsKey(oldName)) {
      _envs.remove(oldName);
      _envs[newName] = MockEnvConfig(newName, true);
    }
  }
}

class MockEnvConfig extends Mock implements EnvConfig {
  final String _name;
  final bool _exists;
  static const LocalFileSystem _fs = LocalFileSystem();
  late final File _updateLockFile;

  MockEnvConfig(this._name, this._exists) {
    _updateLockFile = _fs.file('${_fs.systemTempDirectory.path}/update.lock');
  }

  @override
  String get name => _name;

  @override
  bool get exists => _exists;

  @override
  Directory get envDir => _fs.systemTempDirectory;

  @override
  File get updateLockFile => _updateLockFile;
}

class MockTerminal extends Mock implements Terminal {
  bool get supportsAnsi => false;

  bool get supportsColor => false;

  int get width => 80;

  bool get isTerminal => true;
}

class MockActiveProgressNode extends Mock implements ActiveProgressNode {
  @override
  late final Scope scope;

  MockActiveProgressNode() {
    scope = RootScope();
  }
}

class MockProjectConfig extends Mock implements ProjectConfig {}

class MockProgressNode extends Mock implements ProgressNode {
  late Scope _scope;

  MockProgressNode() {
    _scope = RootScope();
  }

  @override
  Scope get scope => _scope;

  @override
  String render() => '';

  @override
  Future<T> wrap<T>(
    Future<T> Function(Scope scope, ActiveProgressNode node) fn, {
    bool removeWhenComplete = true,
    bool optional = false,
  }) async {
    final fakeNode = MockActiveProgressNode();
    return await fn(scope, fakeNode);
  }

  @override
  void addNode(ProgressNode node) {}
}

class TestEnvSetup {
  final RootScope scope;
  final File prefsFile;

  TestEnvSetup(this.scope, this.prefsFile);

  void tearDown() {
    if (prefsFile.existsSync()) {
      prefsFile.deleteSync();
    }
  }
}

TestEnvSetup setupTestEnv() {
  final logger = HVLogger();
  final mockConfig = MockHavenConfig();
  final mockTerminal = MockTerminal();

  const fs = LocalFileSystem();
  final prefsFile =
      fs.file(
          '${fs.systemTempDirectory.path}/global_prefs_test_${DateTime.now().millisecondsSinceEpoch}.json',
        )
        ..createSync()
        ..writeAsStringSync('{"defaultEnvironment": "stable"}');

  final scope = RootScope();
  scope.add(HVLogger.provider, logger);
  scope.add(HavenConfig.provider, mockConfig);
  scope.add(Terminal.provider, mockTerminal);
  scope.add(ProgressNode.provider, MockProgressNode());
  scope.add(globalPrefsJsonFileProvider, prefsFile);
  scope.add(isFirstRunProvider, false);

  return TestEnvSetup(scope, prefsFile);
}
