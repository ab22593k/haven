import 'package:puro/src/commands/env_create.dart';
import 'package:test/test.dart';

void main() {
  group('EnvCreateCommand', () {
    test('has correct name', () {
      final command = EnvCreateCommand();
      expect(command.name, 'create');
    });

    test('has correct description', () {
      final command = EnvCreateCommand();
      expect(command.description, 'Sets up a new Flutter environment');
    });

    test('parses channel option', () {
      final command = EnvCreateCommand();
      final parser = command.argParser;
      expect(parser.options, contains('channel'));
    });

    test('parses fork option', () {
      final command = EnvCreateCommand();
      final parser = command.argParser;
      expect(parser.options, contains('fork'));
    });
  });
}
