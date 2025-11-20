import 'dart:io';

import 'package:args/command_runner.dart';

import 'command.dart';
import 'command_result.dart';
import 'commands/registry.dart';
import 'logger.dart';
import 'provider.dart';
import 'terminal.dart';

void main(List<String> args) async {
  final scope = RootScope();
  final terminal = Terminal(stdout: stderr);
  scope.add(Terminal.provider, terminal);

  final index = args.indexOf('--');
  final havenArgs = index >= 0 ? args.take(index) : args;
  final isJson = havenArgs.contains('--json');

  final context = HavenCommandContext();

  final runner = HavenCommandRunner(
    'haven',
    'A powerful tool for superintend Flutter versions',
    scope: scope,
    context: context,
    isJson: isJson,
  );

  final log = _setupLogger(isJson, terminal, runner);
  scope.add(HVLogger.provider, log);

  _defineArguments(runner, context, terminal, log);

  registerHavenCommands(runner);
  try {
    final result = await runner.run(args);
    if (result == null) {
      await runner.printUsage();
    } else {
      await runner.writeResultAndExit(result);
    }
  } on CommandError catch (exception, stackTrace) {
    log.v('$stackTrace');
    await runner.writeResultAndExit(exception.result);
  } on UsageException catch (exception) {
    await runner.writeResultAndExit(
      CommandHelpResult(
        didRequestHelp: runner.didRequestHelp,
        help: exception.message,
        usage: exception.usage,
      ),
    );
  } catch (exception, stackTrace) {
    await runner.writeResultAndExit(CommandErrorResult(
      exception,
      stackTrace,
      log.level?.index ?? 0,
    ));
  }
}

HVLogger _setupLogger(
  bool isJson,
  Terminal terminal,
  HavenCommandRunner runner,
) {
  if (isJson) {
    return HVLogger(
      terminal: terminal,
      onAdd: runner.logEntries.add,
    );
  } else {
    final log = HVLogger(
      terminal: terminal,
      level: LogLevel.warning,
    );
    if (Platform.environment.containsKey('HAVEN_LOG_LEVEL')) {
      final logLevel = int.tryParse(Platform.environment['HAVEN_LOG_LEVEL']!);
      if (logLevel != null) {
        log.level = LogLevel.values[logLevel];
      }
    }
    return log;
  }
}

void _defineArguments(
  HavenCommandRunner runner,
  HavenCommandContext context,
  Terminal terminal,
  HVLogger log,
) {
  runner.argParser
    ..addOption(
      'pub-cache-dir',
      help: 'Overrides the pub cache directory',
      valueHelp: 'dir',
      callback: runner.wrapCallback((dir) {
        context.pubCacheOverride = dir;
      }),
    )
    ..addFlag(
      'legacy-pub-cache',
      help: 'Whether to use the legacy pub cache directory',
      callback: runner.wrapCallback((flag) {
        if (runner.results!.wasParsed('legacy-pub-cache')) {
          context.legacyPubCache = flag;
        }
      }),
    )
    ..addOption(
      'git-executable',
      help: 'Overrides the path to the git executable',
      valueHelp: 'exe',
      callback: runner.wrapCallback((exe) {
        context.gitExecutableOverride = exe;
      }),
    )
    ..addOption(
      'root',
      help:
          'Overrides the global Haven root directory. (defaults to `~/.haven` or \$HAVEN_ROOT)',
      valueHelp: 'dir',
      callback: runner.wrapCallback((dir) {
        context.rootDirOverride = dir;
      }),
    )
    ..addOption(
      'dir',
      help: 'Overrides the current working directory',
      valueHelp: 'dir',
      callback: runner.wrapCallback((dir) {
        context.workingDirOverride = dir;
      }),
    )
    ..addOption(
      'project',
      abbr: 'p',
      help: 'Overrides the selected flutter project',
      valueHelp: 'dir',
      callback: runner.wrapCallback((dir) {
        context.projectDirOverride = dir;
      }),
    )
    ..addOption(
      'env',
      abbr: 'e',
      help: 'Overrides the selected environment',
      valueHelp: 'name',
      callback: runner.wrapCallback((name) {
        context.environmentOverride = name?.toLowerCase();
      }),
    )
    ..addOption(
      'flutter-git-url',
      help: 'Overrides the Flutter SDK git url',
      valueHelp: 'url',
      callback: runner.wrapCallback((url) {
        context.flutterGitUrlOverride = url;
      }),
    )
    ..addOption(
      'engine-git-url',
      help: 'Overrides the Flutter Engine git url',
      valueHelp: 'url',
      callback: runner.wrapCallback((url) {
        context.engineGitUrlOverride = url;
      }),
    )
    ..addOption(
      'dart-sdk-git-url',
      help: 'Overrides the Dart SDK git url',
      valueHelp: 'url',
      callback: runner.wrapCallback((url) {
        context.dartSdkGitUrlOverride = url;
      }),
    )
    ..addOption(
      'releases-json-url',
      help: 'Overrides the Flutter releases json url',
      valueHelp: 'url',
      callback: runner.wrapCallback((url) {
        context.versionsJsonUrlOverride = url;
      }),
    )
    ..addOption(
      'flutter-storage-base-url',
      help: 'Overrides the Flutter storage base url',
      valueHelp: 'url',
      callback: runner.wrapCallback((url) {
        context.flutterStorageBaseUrlOverride = url;
      }),
    )
    ..addOption(
      'log-level',
      help: 'Changes how much information is logged to the console, 0 being '
          'no logging at all, and 4 being extremely verbose',
      valueHelp: '0-4',
      callback: runner.wrapCallback((str) {
        if (str == null) return;
        final logLevel = int.parse(str);
        if (logLevel < 0 || logLevel > 4) {
          throw CommandError(
            'Argument `log-level` must be a number between 0 and 4, inclusive',
          );
        }
        log.level = LogLevel.values[logLevel];
      }),
    )
    ..addFlag(
      'log-profile',
      help: 'Enable profiling information in logs',
      callback: runner.wrapCallback((flag) {
        log.profile = flag;
      }),
    )
    ..addFlag(
      'verbose',
      abbr: 'v',
      help: 'Verbose logging, alias for --log-level=3',
      callback: runner.wrapCallback((flag) {
        if (flag) {
          log.level = LogLevel.verbose;
        }
      }),
    )
    ..addFlag(
      'color',
      help: 'Enable or disable ANSI colors',
      callback: runner.wrapCallback((flag) {
        if (runner.results!.wasParsed('color')) {
          terminal.enableColor = flag;
          if (!flag && !runner.results!.wasParsed('progress')) {
            terminal.enableStatus = false;
          }
        }
      }),
    )
    ..addFlag(
      'progress',
      help: 'Enable progress bars',
      callback: runner.wrapCallback((flag) {
        if (runner.results!.wasParsed('progress')) {
          terminal.enableStatus = flag;
        }
      }),
    )
    ..addFlag(
      'json',
      help: 'Output in JSON where possible',
      negatable: false,
    )
    ..addFlag(
      'install',
      help: 'Whether to attempt to install haven',
      callback: runner.wrapCallback((flag) {
        if (runner.results!.wasParsed('install')) {
          context.shouldInstallOverride = runner.results!['install'] as bool;
        }
      }),
    )
    ..addFlag(
      'skip-cache-sync',
      help: 'Whether to skip syncing the Flutter cache',
      callback: runner.wrapCallback((flag) {
        if (runner.results!.wasParsed('skip-cache-sync')) {
          context.shouldSkipCacheSyncOverride = flag;
        }
      }),
    )
    ..addFlag(
      'version',
      help: 'Prints version information, same as the `version` command',
      negatable: false,
    )
    ..addFlag(
      'no-update-check',
      help: 'Skip update check',
      negatable: false,
      callback: runner.wrapCallback((flag) {
        context.allowUpdateCheckOverride = !flag;
      }),
    );
}
