import 'package:haven/src/commands/env_use.dart';
import 'package:test/test.dart';

void main() {
  group('EnvUseCommand', () {
    test('has correct name', () {
      final command = EnvUseCommand();
      expect(command.name, 'use');
    });

    test('has correct description', () {
      final command = EnvUseCommand();
      expect(
        command.description,
        'Selects an environment to use in the current project',
      );
    });

    test('parses vscode option', () {
      final command = EnvUseCommand();
      final parser = command.argParser;
      expect(parser.options, contains('vscode'));
    });

    test('parses intellij option', () {
      final command = EnvUseCommand();
      final parser = command.argParser;
      expect(parser.options, contains('intellij'));
    });

    test('parses global flag', () {
      final command = EnvUseCommand();
      final parser = command.argParser;
      expect(parser.options, contains('global'));
    });
  });
}
