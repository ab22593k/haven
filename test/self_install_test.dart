import 'package:haven/src/commands/self_install.dart';
import 'package:test/test.dart';

void main() {
  group('Self install command', () {
    test('has correct name', () {
      final command = SelfInstallCommand();
      expect(command.name, 'install-haven');
    });

    test('is hidden', () {
      final command = SelfInstallCommand();
      expect(command.hidden, isTrue);
    });

    test('has correct description', () {
      final command = SelfInstallCommand();
      expect(command.description, 'Finishes installation of the haven tool');
    });

    test('parses force flag', () {
      final command = SelfInstallCommand();
      final parser = command.argParser;
      expect(parser.options, contains('force'));
    });

    test('parses promote flag', () {
      final command = SelfInstallCommand();
      final parser = command.argParser;
      expect(parser.options, contains('promote'));
    });

    test('parses path flag', () {
      final command = SelfInstallCommand();
      final parser = command.argParser;
      expect(parser.options, contains('path'));
    });

    test('parses profile option', () {
      final command = SelfInstallCommand();
      final parser = command.argParser;
      expect(parser.options, contains('profile'));
    });
  });
}
