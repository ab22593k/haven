import 'package:haven/src/commands/env_rm.dart';
import 'package:test/test.dart';

void main() {
  group('EnvRmCommand', () {
    test('has correct name', () {
      final command = EnvRmCommand();
      expect(command.name, 'rm');
    });

    test('has correct description', () {
      final command = EnvRmCommand();
      expect(command.description, 'Deletes an environment');
    });

    test('parses force flag', () {
      final command = EnvRmCommand();
      final parser = command.argParser;
      expect(parser.options, contains('force'));
    });
  });
}
