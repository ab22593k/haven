import '../ast/binary.dart';
import '../command.dart';
import '../command_result.dart';
import '../config/config.dart';
import '../env/git_operations_service.dart';
import '../process.dart';
import '../terminal.dart';
import 'ast_generator.dart';
import 'binary_md_processor.dart';
import 'dart_release_manager.dart';
import 'git_operations.dart';
import 'snapshot_reader.dart';

class GenerateASTParserCommand extends HavenCommand {
  @override
  String get name => '_generate-ast-parser';

  @override
  Future<CommandResult> run() async {
    final config = HavenConfig.of(scope);
    final sharedRepository = config.sharedDartSdkDir;
    final workingDir = config.fileSystem.directory('temp_ast_gen');
    if (!sharedRepository.existsSync()) {
      await const GitOperationsService().fetchOrCloneShared(
        scope: scope,
        repository: sharedRepository,
        remoteUrl: config.dartSdkGitUrl,
      );
    }

    final gitOps = GitOperations(scope: scope);
    final binaryMdCommits = await gitOps.fetchBinaryMdCommits();

    final processor = BinaryMdProcessor(scope: scope);
    final verSchema = await processor.processCommits(binaryMdCommits);

    // Generate separate ASTs for every version (for debugging)
    final astsDir = workingDir.childDirectory('asts');
    if (astsDir.existsSync()) astsDir.deleteSync(recursive: true);
    astsDir.createSync(recursive: true);
    for (final entry in verSchema.entries) {
      final ast = generateAstForSchemas(
        {entry.key: entry.value},
        comment: 'For schema ${entry.key}',
      );
      astsDir.childFile('v${entry.key}.dart').writeAsStringSync(ast);
    }

    // Generate diffs (for debugging)
    final diffsDir = workingDir.childDirectory('diffs');
    if (diffsDir.existsSync()) diffsDir.deleteSync(recursive: true);
    diffsDir.createSync(recursive: true);
    for (final entry in verSchema.entries.skip(1)) {
      final diff = await runProcess(
        scope,
        'diff',
        [
          '--context',
          '-F',
          '^class',
          '--label',
          'v${entry.key}',
          '--label',
          'v${entry.key - 1}',
          astsDir.childFile('v${entry.key - 1}.dart').path,
          astsDir.childFile('v${entry.key}.dart').path,
        ],
        debugLogging: false,
      );
      if (diff.exitCode > 1) {
        return BasicMessageResult(
          'Failed to generate diff:\n${diff.stderr}',
          type: CompletionType.failure,
        );
      }
      diffsDir.childFile('v${entry.key}.diff').writeAsStringSync(diff.stdout as String);
    }

    // Download Dart
    final releaseManager = DartReleaseManager(scope: scope);
    await releaseManager.downloadReleases();

    // Generate binary formats for each version
    final formats = <int, BinFormat>{};
    for (final entry in verSchema.entries) {
      formats[entry.key] = BinFormat.fromSchema(entry.value);
    }

    // Read snapshots
    final snapshotReader = SnapshotReader(scope: scope);
    await snapshotReader.readSnapshots(formats);

    return BasicMessageResult('Generated AST parser');
  }
}
