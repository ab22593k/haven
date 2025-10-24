import 'package:puro/src/commands/puro_install.dart';
import 'package:test/test.dart';

void main() {
  group('PuroInstallCommand', () {
    test('has correct name', () {
      final command = PuroInstallCommand();
      expect(command.name, 'install-puro');
    });

    test('is hidden', () {
      final command = PuroInstallCommand();
      expect(command.hidden, isTrue);
    });

    test('has correct description', () {
      final command = PuroInstallCommand();
      expect(command.description, 'Finishes installation of the puro tool');
    });

    test('parses force flag', () {
      final command = PuroInstallCommand();
      final parser = command.argParser;
      expect(parser.options, contains('force'));
    });

    test('parses promote flag', () {
      final command = PuroInstallCommand();
      final parser = command.argParser;
      expect(parser.options, contains('promote'));
    });

    test('parses path flag', () {
      final command = PuroInstallCommand();
      final parser = command.argParser;
      expect(parser.options, contains('path'));
    });

    test('parses profile option', () {
      final command = PuroInstallCommand();
      final parser = command.argParser;
      expect(parser.options, contains('profile'));
    });
  });
}
