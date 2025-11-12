import 'package:puro/src/command_result.dart';
import 'package:puro/src/config/config.dart';

import 'package:puro/src/env/service.dart';

import 'package:test/test.dart';

import 'env_test_utils.dart';

void main() {
  group('EnvService', () {
    late TestEnvSetup testEnv;
    late EnvService service;
    late MockPuroConfig mockConfig;

    setUp(() {
      testEnv = setupTestEnv();
      service = const EnvService();
      mockConfig = testEnv.scope.read(PuroConfig.provider) as MockPuroConfig;
    });

    tearDown(() {
      testEnv.tearDown();
    });

    test('getDefaultEnvName returns current default', () async {
      final defaultName = await service.getDefaultEnvName(scope: testEnv.scope);
      expect(defaultName, 'stable'); // From the initial prefs
    });

    test('setDefaultEnv sets default for existing env', () async {
      final mockEnv = MockEnvConfig('test-env', true);
      mockConfig.addEnv('test-env', mockEnv);

      final result =
          await service.setDefaultEnv(scope: testEnv.scope, envName: 'test-env');
      expect(result, 'Set global default environment to `test-env`');

      final defaultName = await service.getDefaultEnvName(scope: testEnv.scope);
      expect(defaultName, 'test-env');
    });

    test('setDefaultEnv with null returns current default', () async {
      final result = await service.setDefaultEnv(scope: testEnv.scope, envName: null);
      expect(result, 'stable');
    });

    test('setDefaultEnv throws for non-existent env', () async {
      await expectLater(
        service.setDefaultEnv(scope: testEnv.scope, envName: 'non-existent-env'),
        throwsA(isA<CommandError>()),
      );
    });

    test('createEnv validates env name', () async {
      // Test that createEnv calls ensureValidEnvName (indirectly tested by throwing)
      await expectLater(
        service.createEnv(
          scope: testEnv.scope,
          envName: 'invalid name with spaces',
        ),
        throwsA(anything), // Should throw due to invalid name
      );
    });


  });
}
