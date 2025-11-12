import 'package:args/args.dart';

import '../command.dart';
import '../command_result.dart';
import 'dart_service.dart';

class DartCommand extends PuroCommand {
  @override
  final name = 'dart';

  @override
  final description = 'Forwards arguments to dart in the current environment';

  @override
  final argParser = ArgParser.allowAnything();

  @override
  String? get argumentUsage => '[...args]';

  @override
  Future<CommandResult> run() async {
    const service = DartCommandService();
    final exitCode = await service.executeDartCommand(
      scope: scope,
      args: argResults!.arguments,
    );
    await runner.exitPuro(exitCode);
  }
}
