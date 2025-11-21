import 'dart:convert';

import 'package:file/file.dart';

import '../config/config.dart';
import '../git.dart';
import '../provider.dart';

class GitOperations {
  GitOperations({required this.scope});

  final Scope scope;
  late final config = HavenConfig.of(scope);
  late final git = GitClient.of(scope);

  Future<Map<String, String>> fetchBinaryMdCommits() async {
    final sharedRepository = config.sharedDartSdkDir;
    final binaryMdResult = await git.raw([
      'log',
      '--format=%H',
      '8dbe716085d4942ce87bd34e933cfccf2d0f70ae..main',
      '--',
      'pkg/kernel/binary.md',
    ], directory: sharedRepository);
    final commits = (binaryMdResult.stdout as String)
        .trim()
        .split('\n')
        .reversed
        .toList();
    commits.add(
      await git.getCurrentCommitHash(repository: sharedRepository, branch: 'main'),
    );

    final binaryMdDir = config.fileSystem
        .directory('temp_ast_gen')
        .childDirectory('binary-md');
    if (!binaryMdDir.existsSync()) {
      binaryMdDir.createSync(recursive: true);
      for (final line in (binaryMdResult.stdout as String).trim().split('\n')) {
        final versionContents = await git.cat(
          repository: sharedRepository,
          path: 'tools/VERSION',
          ref: line,
        );
        final major = RegExp(
          r'MAJOR (\d+)',
        ).firstMatch(utf8.decode(versionContents))![1]!;
        if (major == '1') continue;
        final contents = await git.cat(
          repository: sharedRepository,
          path: 'pkg/kernel/binary.md',
          ref: line,
        );
        final lines = <String>[];
        var inCodeBlock = false;
        for (final line in utf8.decode(contents).split('\n')) {
          if (line.startsWith('```')) {
            inCodeBlock = !inCodeBlock;
          } else if (inCodeBlock) {
            lines.add(line);
          }
        }
        binaryMdDir.childFile('$line.md').writeAsStringSync(lines.join('\n'));
      }
    }

    final binaryMdCommits = <String, String>{};
    for (final childFile in binaryMdDir.listSync()) {
      if (childFile is! File || !childFile.basename.endsWith('.md')) continue;
      final contents = childFile.readAsStringSync();
      final commit = childFile.basename.substring(0, childFile.basename.length - 3);
      binaryMdCommits[commit] = contents;
    }

    return binaryMdCommits;
  }
}
