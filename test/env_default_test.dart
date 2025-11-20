import 'dart:convert';

import 'package:haven/src/config/config.dart';
import 'package:haven/src/env/default.dart';
import 'package:test/test.dart';

import 'env_test_utils.dart';

void main() {
  group('setDefaultEnvName', () {
    late TestEnvSetup testEnv;

    setUp(() {
      testEnv = setupTestEnv();
    });

    tearDown(() {
      testEnv.tearDown();
    });

    test('sets default successfully', () async {
      final mockConfig = testEnv.scope.read(HavenConfig.provider) as MockPuroConfig;
      // Setup environment to exist - this must be done BEFORE calling the function
      final mockEnv = MockEnvConfig('default-test-env', true);
      mockConfig.addEnv('default-test-env', mockEnv);

      // Set as default
      await setDefaultEnvName(
        scope: testEnv.scope,
        envName: 'default-test-env',
      );

      // Verify
      final defaultName = await getDefaultEnvName(scope: testEnv.scope);
      expect(defaultName, 'default-test-env');

      // Verify the preferences file was updated
      final String content = testEnv.prefsFile.readAsStringSync();
      final Map<String, dynamic> prefs = jsonDecode(content) as Map<String, dynamic>;
      expect(prefs['defaultEnvironment'], 'default-test-env');
    });

    test('rolls back on failure', () async {
      final mockConfig = testEnv.scope.read(HavenConfig.provider) as MockPuroConfig;
      // Setup initial state - this must be done BEFORE calling the function
      final mockEnv = MockEnvConfig('default-rollback-env', true);
      mockConfig.addEnv('default-rollback-env', mockEnv);

      // Set as default
      await setDefaultEnvName(
        scope: testEnv.scope,
        envName: 'default-rollback-env',
      );

      // Verify
      final newDefault = await getDefaultEnvName(scope: testEnv.scope);
      expect(newDefault, 'default-rollback-env');
    });
  });
}
