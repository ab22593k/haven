import 'dart:convert';

import 'package:file/file.dart';
import 'package:file/local.dart';
import 'package:mockito/mockito.dart';
import 'package:puro/src/config/config.dart';
import 'package:puro/src/config/prefs.dart';
import 'package:puro/src/env/default.dart';
import 'package:puro/src/logger.dart';
import 'package:puro/src/progress.dart';
import 'package:puro/src/provider.dart';
import 'package:puro/src/terminal.dart';
import 'package:test/test.dart';

class MockPuroConfig extends Mock implements PuroConfig {
  final Map<String, MockEnvConfig> _envs = {};
  final LocalFileSystem _fs = const LocalFileSystem();
  late final Link _defaultEnvLink;

  MockPuroConfig() {
    _defaultEnvLink = _fs.link('${_fs.systemTempDirectory.path}/default_env_link');
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

void main() {
  group('setDefaultEnvName', () {
    late RootScope scope;
    late PuroLogger logger;
    late MockPuroConfig mockConfig;
    late MockTerminal mockTerminal;
    late File prefsFile;

    setUp(() {
      logger = PuroLogger();
      mockConfig = MockPuroConfig();
      mockTerminal = MockTerminal();

      // Use LocalFileSystem to create a temporary file for preferences
      const fs = LocalFileSystem();
      prefsFile = fs.file(fs.systemTempDirectory.path + '/global_prefs_test.json')
        ..createSync()
        ..writeAsStringSync('{"defaultEnvironment": "stable"}');

      scope = RootScope();
      scope.add(PuroLogger.provider, logger);
      scope.add(PuroConfig.provider, mockConfig);
      scope.add(Terminal.provider, mockTerminal);
      scope.add(ProgressNode.provider, MockProgressNode());
      scope.add(globalPrefsJsonFileProvider, prefsFile);
      scope.add(isFirstRunProvider, false); // Add the missing provider
    });

    tearDown(() {
      // Clean up the temporary file
      if (prefsFile.existsSync()) {
        prefsFile.deleteSync();
      }
    });

    test('sets default successfully', () async {
      // Setup environment to exist - this must be done BEFORE calling the function
      final mockEnv = MockEnvConfig('default-test-env', true);
      mockConfig.addEnv('default-test-env', mockEnv);

      // Set as default
      await setDefaultEnvName(
        scope: scope,
        envName: 'default-test-env',
      );

      // Verify
      final defaultName = await getDefaultEnvName(scope: scope);
      expect(defaultName, 'default-test-env');

      // Verify the preferences file was updated
      final String content = prefsFile.readAsStringSync();
      final Map<String, dynamic> prefs = jsonDecode(content) as Map<String, dynamic>;
      expect(prefs['defaultEnvironment'], 'default-test-env');
    });

    test('rolls back on failure', () async {
      // Setup initial state - this must be done BEFORE calling the function
      final mockEnv = MockEnvConfig('default-rollback-env', true);
      mockConfig.addEnv('default-rollback-env', mockEnv);

      // Set as default
      await setDefaultEnvName(
        scope: scope,
        envName: 'default-rollback-env',
      );

      // Verify
      final newDefault = await getDefaultEnvName(scope: scope);
      expect(newDefault, 'default-rollback-env');
    });
  });
}
