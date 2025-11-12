import 'package:args/args.dart';

import '../command.dart';
import '../command_result.dart';
import 'pub_service.dart';

class PubCommand extends PuroCommand {
  @override
  final name = 'pub';

  @override
  final description = 'Forwards arguments to pub in the current environment';

  @override
  final argParser = ArgParser.allowAnything();

  @override
  String? get argumentUsage => '[...args]';

  @override
  Future<CommandResult> run() async {
    const service = PubCommandService();
    final exitCode = await service.executePubCommand(
      scope: scope,
      args: argResults!.arguments,
    );
    await runner.exitPuro(exitCode);
  }
}
