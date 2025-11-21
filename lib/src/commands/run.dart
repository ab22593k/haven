import 'package:args/args.dart';

import '../command.dart';
import '../command_result.dart';
import 'run_service.dart';

class RunCommand extends HavenCommand {
  @override
  final name = 'run';

  @override
  final description = 'Forwards arguments to dart run in the current environment';

  @override
  final argParser = ArgParser.allowAnything();

  @override
  String? get argumentUsage => '[...args]';

  @override
  Future<CommandResult> run() async {
    const service = RunCommandService();
    await service.runScript(scope: scope, runner: runner, args: argResults!.arguments);
    // This won't be reached as exitHaven terminates the program
    throw UnimplementedError('Unreachable code');
  }
}
