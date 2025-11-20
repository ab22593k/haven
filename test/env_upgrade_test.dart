import 'package:haven/src/commands/env_upgrade.dart';
import 'package:test/test.dart';

void main() {
  group('EnvUpgradeCommand', () {
    test('has correct name', () {
      final command = EnvUpgradeCommand();
      expect(command.name, 'upgrade');
    });

    test('has correct aliases', () {
      final command = EnvUpgradeCommand();
      expect(command.aliases, ['downgrade']);
    });

    test('has correct description', () {
      final command = EnvUpgradeCommand();
      expect(command.description,
          'Upgrades or downgrades an environment to a new version of Flutter');
    });

    test('parses channel option', () {
      final command = EnvUpgradeCommand();
      final parser = command.argParser;
      expect(parser.options, contains('channel'));
    });

    test('parses force flag', () {
      final command = EnvUpgradeCommand();
      final parser = command.argParser;
      expect(parser.options, contains('force'));
    });
  });
}
