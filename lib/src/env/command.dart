import 'dart:async';
import 'dart:io';

import '../config/config.dart';
import '../provider.dart';
import 'command_runner.dart';

/// Runs a Flutter command in the given environment.
Future<int> runFlutterCommand({
  required Scope scope,
  required EnvConfig environment,
  required List<String> args,
  Stream<List<int>>? stdin,
  void Function(List<int>)? onStdout,
  void Function(List<int>)? onStderr,
  String? workingDirectory,
  ProcessStartMode mode = ProcessStartMode.normal,
}) {
  return const FlutterCommandRunner().runCommand(
    scope: scope,
    environment: environment,
    args: args,
    stdin: stdin,
    onStdout: onStdout,
    onStderr: onStderr,
    workingDirectory: workingDirectory,
    mode: mode,
  );
}

/// Runs a Dart command in the given environment.
Future<int> runDartCommand({
  required Scope scope,
  required EnvConfig environment,
  required List<String> args,
  Stream<List<int>>? stdin,
  void Function(List<int>)? onStdout,
  void Function(List<int>)? onStderr,
  String? workingDirectory,
  ProcessStartMode mode = ProcessStartMode.normal,
}) {
  return const DartCommandRunner().runCommand(
    scope: scope,
    environment: environment,
    args: args,
    stdin: stdin,
    onStdout: onStdout,
    onStderr: onStderr,
    workingDirectory: workingDirectory,
    mode: mode,
  );
}
