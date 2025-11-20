import 'dart:io';

import 'package:args/args.dart';

import '../command.dart';
import '../command_result.dart';
import 'flutter_service.dart';

class FlutterCommand extends HavenCommand {
  @override
  final name = 'flutter';

  @override
  final description = 'Forwards arguments to flutter in the current environment';

  @override
  final argParser = ArgParser.allowAnything();

  @override
  String? get argumentUsage => '[...args]';

  @override
  Future<CommandResult> run() async {
    const service = FlutterCommandService();
    final exitCode = await service.executeFlutterCommand(
      scope: scope,
      runner: runner,
      args: argResults!.arguments,
    );
    exit(exitCode);
  }
}
