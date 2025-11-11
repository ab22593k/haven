import 'package:puro/src/config/prefs.dart';
import 'package:puro/src/logger.dart';
import 'package:test/test.dart';

void main() {
  group('Prefs JSON parsing', () {
    late TestLogger logger;

    setUp(() {
      logger = TestLogger();
    });

    test('parses valid JSON', () {
      const json = '{"key": "value"}';
      final result = parsePrefsJson(json, logger);
      expect(result, {'key': 'value'});
      expect(logger.warnings, isEmpty);
    });

    test('handles empty content', () {
      const json = '';
      final result = parsePrefsJson(json, logger);
      expect(result, isNull);
      expect(logger.warnings, isEmpty);
    });

    test('handles whitespace only', () {
      const json = '   \n\t  ';
      final result = parsePrefsJson(json, logger);
      expect(result, isNull);
      expect(logger.warnings, isEmpty);
    });

    test('parses complex valid JSON', () {
      const json = '''
{
  "defaultEnvironment": "stable",
  "lastUpdateCheck": "2025-10-27T13:27:31.098027",
  "projectDotfiles": [
    "/path/to/file1",
    "/path/to/file2"
  ],
  "legacyPubCache": true
}
''';
      final result = parsePrefsJson(json, logger);
      expect(result, {
        'defaultEnvironment': 'stable',
        'lastUpdateCheck': '2025-10-27T13:27:31.098027',
        'projectDotfiles': ['/path/to/file1', '/path/to/file2'],
        'legacyPubCache': true,
      });
      expect(logger.warnings, isEmpty);
    });

    test('handles concatenated JSON by using first object', () {
      const json = '''
{
  "defaultEnvironment": "stable",
  "legacyPubCache": true
}
{
  "legacyPubCache": false
}
''';
      final result = parsePrefsJson(json, logger);
      expect(result, {
        'defaultEnvironment': 'stable',
        'legacyPubCache': true,
      });
      expect(logger.warnings, hasLength(1));
      expect(logger.warnings.first, contains('concatenated'));
    });

    test('handles JSON with trailing garbage', () {
      const json = '''
{
  "key": "value"
}
some trailing text
''';
      final result = parsePrefsJson(json, logger);
      expect(result, {'key': 'value'});
      expect(logger.warnings, hasLength(1));
      expect(logger.warnings.first, contains('concatenated'));
    });

    test('handles malformed JSON', () {
      const json = '{ invalid json }';
      final result = parsePrefsJson(json, logger);
      expect(result, isNull);
      expect(logger.warnings, hasLength(1));
      expect(logger.warnings.first, contains('corrupted'));
    });

    test('handles JSON not an object', () {
      const json = '[1, 2, 3]';
      final result = parsePrefsJson(json, logger);
      expect(result, isNull);
      expect(logger.warnings, hasLength(1));
      expect(logger.warnings.first, contains('not a valid object'));
    });

    test('handles nested objects correctly', () {
      const json = '''
{
  "nested": {
    "key": "value"
  },
  "array": [1, 2, {"inner": "obj"}]
}
trailing
''';
      final result = parsePrefsJson(json, logger);
      expect(result, {
        'nested': {'key': 'value'},
        'array': [
          1,
          2,
          {'inner': 'obj'}
        ],
      });
      expect(logger.warnings, hasLength(1));
    });

    test('ignores strings with braces', () {
      const json = '''
{
  "description": "This has { and } in it",
  "key": "value"
}
{
  "other": "object"
}
''';
      final result = parsePrefsJson(json, logger);
      expect(result, {
        'description': 'This has { and } in it',
        'key': 'value',
      });
      expect(logger.warnings, hasLength(1));
    });

    test('handles the exact corrupted content from issue', () {
      const json = '''{
  "defaultEnvironment": "stable",
  "lastUpdateCheck": "2025-10-27T13:27:31.098027",
  "projectDotfiles": [
    "/dummy/path1/.puro.json",
    "/dummy/path2/.puro.json",
    "/dummy/path3/.puro.json",
    "/dummy/path4/.puro.json"
  ],
  "legacyPubCache": true
}
{
  "legacyPubCache": true
}''';
      final result = parsePrefsJson(json, logger);
      expect(result, {
        'defaultEnvironment': 'stable',
        'lastUpdateCheck': '2025-10-27T13:27:31.098027',
        'projectDotfiles': [
          '/dummy/path1/.puro.json',
          '/dummy/path2/.puro.json',
          '/dummy/path3/.puro.json',
          '/dummy/path4/.puro.json'
        ],
        'legacyPubCache': true,
      });
      expect(logger.warnings, hasLength(1));
      expect(logger.warnings.first, contains('concatenated'));
    });
  });
}

class TestLogger extends PuroLogger {
  final warnings = <String>[];

  TestLogger() : super(level: LogLevel.verbose);

  @override
  void w(Object? message) {
    warnings.add(message.toString());
  }
}
