import 'dart:convert';

import 'package:petitparser/petitparser.dart';

import '../ast/grammar.dart';
import '../command_result.dart';
import '../config/config.dart';
import '../provider.dart';
import '../terminal.dart';

class BinaryMdProcessor {
  BinaryMdProcessor({required this.scope});

  final Scope scope;

  Future<Map<int, dynamic>> processCommits(Map<String, String> binaryMdCommits) async {
    final verSchema = <int, dynamic>{};

    final workingDir = HavenConfig.of(scope).fileSystem.directory('temp_ast_gen');
    final astsJsonDir = workingDir.childDirectory('asts-json');
    if (!astsJsonDir.existsSync()) {
      astsJsonDir.createSync(recursive: true);
    }

    for (final entry in binaryMdCommits.entries) {
      var source = entry.value;
      source = source.replaceAllMapped(
        RegExp('/\\*(\nenum[\\s\\S]+?)\\*/', multiLine: true),
        (match) => match.group(1)!,
      );

      source.replaceAll(
        'enum LogicalOperator { &&, || }',
        'enum LogicalOperator { logicalAnd, logicalOr }',
      );

      final result = BinaryMdGrammar().build().parse(source);
      if (result is Failure) {
        return Future.error(
          BasicMessageResult(
            'Failed to parse AST parser:\n$result',
            type: CompletionType.failure,
          ),
        );
      }

      final componentFile = (result.value as List).singleWhere((e) {
        return e['type'] != null && e['type'][1] == 'ComponentFile';
      });
      final version = int.parse(
        (componentFile['type'][3] as List).singleWhere(
              (e) => e['field'] != null && e['field'][1] == 'formatVersion',
            )['field'][2]
            as String,
      );

      verSchema[version] = result.value;

      astsJsonDir
          .childFile('v$version.json')
          .writeAsStringSync(const JsonEncoder.withIndent('  ').convert(result.value));
    }

    return verSchema;
  }
}
