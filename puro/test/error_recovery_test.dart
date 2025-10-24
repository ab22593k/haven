import 'package:puro/src/command_result.dart';
import 'package:test/test.dart';

void main() {
  group('Error Recovery', () {
    test('NetworkError has correct message', () {
      final error = NetworkError('Connection failed');
      expect(error.toString(), contains('Network error: Connection failed'));
    });

    test('FileSystemError has correct message', () {
      final error = FileSystemError('Permission denied');
      expect(error.toString(), contains('File system error: Permission denied'));
    });

    test('EnvironmentError has correct message', () {
      final error = EnvironmentError('Invalid state');
      expect(error.toString(), contains('Environment error: Invalid state'));
    });

    // TODO: Add integration tests for cleanup on failure
    test('cleanup placeholder', () {
      expect(true, isTrue);
    });
  });
}
