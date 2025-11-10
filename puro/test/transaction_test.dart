import 'package:puro/src/env/transaction.dart';
import 'package:puro/src/logger.dart';
import 'package:puro/src/provider.dart';
import 'package:test/test.dart';

void main() {
  group('EnvTransaction', () {
    test('runs successfully', () async {
      final log = PuroLogger();
      final scope = RootScope();
      scope.add(PuroLogger.provider, log);
      var executed = false;
      await EnvTransaction.run(
          scope: scope,
          body: (tx) async {
            await tx.step(
              label: 'test',
              action: () async {
                executed = true;
              },
              rollback: null,
            );
          });
      expect(executed, true);
    });

    test('rolls back on failure', () async {
      final log = PuroLogger();
      final scope = RootScope();
      scope.add(PuroLogger.provider, log);
      var rolledBack = false;
      try {
        await EnvTransaction.run(
            scope: scope,
            body: (tx) async {
              await tx.step(
                label: 'success step',
                action: () async {},
                rollback: () async {
                  rolledBack = true;
                },
              );
              await tx.step(
                label: 'fail step',
                action: () async {
                  throw Exception('fail');
                },
                rollback: null,
              );
            });
      } catch (e) {
        expect(e.toString(), contains('fail'));
      }
      expect(rolledBack, true);
    });

    test('rolls back multiple steps on failure', () async {
      final log = PuroLogger();
      final scope = RootScope();
      scope.add(PuroLogger.provider, log);
      var step1RolledBack = false;
      var step2RolledBack = false;
      try {
        await EnvTransaction.run(
            scope: scope,
            body: (tx) async {
              await tx.step(
                label: 'step 1',
                action: () async {},
                rollback: () async {
                  step1RolledBack = true;
                },
              );
              await tx.step(
                label: 'step 2',
                action: () async {},
                rollback: () async {
                  step2RolledBack = true;
                },
              );
              await tx.step(
                label: 'fail step',
                action: () async {
                  throw Exception('fail');
                },
                rollback: null,
              );
            });
      } catch (e) {
        expect(e.toString(), contains('fail'));
      }
      expect(step1RolledBack, true);
      expect(step2RolledBack, true);
    });
  });
}
