import 'dart:io';

import '../models.dart';
import 'provider.dart';
import 'terminal.dart';

extension CommandResultModelExtensions on CommandResultModel {
  void addMessage(CommandMessage message, OutputFormatter format) {
    messages.add(
      CommandMessageModel(
        type:
            (message.type ??
                    (success ? CompletionType.success : CompletionType.failure))
                .name,
        message: message.message(format),
      ),
    );
  }

  void addMessages(Iterable<CommandMessage> messages, OutputFormatter format) {
    for (final message in messages) {
      addMessage(message, format);
    }
  }
}

class CommandErrorResult extends InternalErrorResult {
  CommandErrorResult(this.exception, StackTrace stackTrace, this.logLevel)
    : super(
        message: '$exception\n$stackTrace',
        error: exception,
        stackTrace: stackTrace,
      );

  final Object exception;
  final int? logLevel;

  @override
  Iterable<CommandMessage> get messages {
    return [
      CommandMessage('$exception\n$stackTrace'),
      CommandMessage(
        [
          'Haven crashed! Please file an issue at https://github.com/ab22593k/haven',
          if (logLevel != null && logLevel! < 4)
            'Consider running the command with a higher log level: `--log-level=4`',
        ].join('\n'),
      ),
    ];
  }
}

class CommandHelpResult extends HelpResult {
  CommandHelpResult({required bool didRequestHelp, String? help, String? usage})
    : super(didRequestHelp: didRequestHelp, description: help, usage: usage);
}

class BasicMessageResult extends MessageResult {
  BasicMessageResult(String message, {bool success = true, CompletionType? type})
    : super(
        messages: [CommandMessage(message, type: type)],
        success: success,
      );

  BasicMessageResult.format(
    String Function(OutputFormatter format) message, {
    bool success = true,
    CompletionType? type,
  }) : super(
         messages: [CommandMessage.format(message, type: type)],
         success: success,
       );

  BasicMessageResult.list(List<CommandMessage> messages, {bool success = true})
    : super(messages: messages, success: success);
}

sealed class CommandResult {
  const CommandResult();

  int get exitCode;

  Iterable<CommandMessage> get messages;

  CommandResultModel? get model => null;

  CommandResultModel toModel([OutputFormatter format = plainFormatter]) {
    final result = CommandResultModel();
    if (model != null) {
      result.mergeFromMessage(model!);
    }
    result.success = exitCode == 0;
    result.addMessages(messages, format);
    return result;
  }

  @override
  String toString() => CommandMessage.formatMessages(
    messages: messages,
    format: plainFormatter,
    success: toModel().success,
  );
}

class SuccessResult extends CommandResult {
  const SuccessResult({this.messages = const []});

  @override
  int get exitCode => 0;

  @override
  final List<CommandMessage> messages;

  @override
  CommandResultModel? get model => null;
}

class HelpResult extends CommandResult {
  const HelpResult({this.usage, this.description, this.didRequestHelp = true});

  final String? usage;
  final String? description;
  final bool didRequestHelp;

  @override
  int get exitCode => didRequestHelp ? 0 : 1;

  @override
  Iterable<CommandMessage> get messages => [
    if (description != null) CommandMessage(description!, type: CompletionType.failure),
    if (usage != null)
      CommandMessage(
        usage!,
        type: didRequestHelp ? CompletionType.plain : CompletionType.info,
      ),
  ];

  @override
  CommandResultModel? get model => CommandResultModel(usage: usage);
}

class UserErrorResult extends CommandResult {
  const UserErrorResult({required this.message, this.showUsage = false});

  final String message;
  final bool showUsage;

  @override
  int get exitCode => 1;

  @override
  Iterable<CommandMessage> get messages => [
    CommandMessage(message, type: CompletionType.failure),
    if (showUsage)
      CommandMessage('Run with --help for usage.', type: CompletionType.info),
  ];

  @override
  CommandResultModel? get model => null;
}

class InternalErrorResult extends CommandResult {
  const InternalErrorResult({required this.message, this.error, this.stackTrace});

  final String message;
  final Object? error;
  final StackTrace? stackTrace;

  @override
  int get exitCode => 1;

  @override
  Iterable<CommandMessage> get messages => [
    CommandMessage(message, type: CompletionType.failure),
    if (error != null) CommandMessage('$error', type: CompletionType.failure),
    if (stackTrace != null) CommandMessage('$stackTrace', type: CompletionType.failure),
    CommandMessage(
      'Haven crashed! Please file an issue at https://github.com/ab22593k/haven',
      type: CompletionType.failure,
    ),
  ];

  @override
  CommandResultModel? get model => CommandResultModel(
    error: CommandErrorModel(
      exception: error?.toString() ?? message,
      exceptionType: error?.runtimeType.toString() ?? 'Unknown',
      stackTrace: stackTrace?.toString(),
    ),
  );
}

class MessageResult extends CommandResult {
  const MessageResult({required this.messages, this.success = true});

  @override
  final List<CommandMessage> messages;
  final bool success;

  @override
  int get exitCode => success ? 0 : 1;

  @override
  CommandResultModel? get model => null;
}

class CommandMessage {
  CommandMessage(String message, {this.type}) : message = ((format) => message);
  CommandMessage.format(this.message, {this.type});

  final CompletionType? type;
  final String Function(OutputFormatter format) message;

  static String formatMessages({
    required Iterable<CommandMessage> messages,
    required OutputFormatter format,
    required bool success,
  }) {
    return messages
        .map(
          (e) => format.complete(
            e.message(format),
            type: e.type ?? (success ? CompletionType.success : CompletionType.failure),
          ),
        )
        .join('\n');
  }

  static final provider = Provider<void Function(CommandMessage)>(
    (scope) => (message) {},
  );

  void queue(Scope scope) => scope.read(provider)(this);
}

/// Like [CommandResult] but thrown as an exception.
class CommandError implements Exception {
  CommandError(String message, {CompletionType? type, bool success = false})
    : result = BasicMessageResult(message, success: success, type: type);

  CommandError.format(
    String Function(OutputFormatter format) message, {
    CompletionType? type,
    bool success = false,
  }) : result = BasicMessageResult.format(message, success: success, type: type);

  CommandError.list(List<CommandMessage> messages, {bool success = false})
    : result = BasicMessageResult.list(messages, success: success);

  final CommandResult result;

  @override
  String toString() => result.toString();
}

class UnsupportedOSError extends CommandError {
  UnsupportedOSError() : super('Unsupported OS: `${Platform.operatingSystem}`');
}

class NetworkError extends CommandError {
  NetworkError(String message) : super('Network error: $message');
}

class FileSystemError extends CommandError {
  FileSystemError(String message) : super('File system error: $message');
}

class EnvironmentError extends CommandError {
  EnvironmentError(String message) : super('Environment error: $message');
}
