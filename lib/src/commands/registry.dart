import '../command.dart';
import 'build_shell.dart';
import 'clean.dart';
import 'dart.dart';
import 'engine.dart';
import 'env_create.dart';
import 'env_ls.dart';
import 'env_rename.dart';
import 'env_rm.dart';
import 'env_upgrade.dart';
import 'env_use.dart';
import 'eval.dart';
import 'flutter.dart';
import 'gc.dart';
import 'internal_generate_ast_parser.dart';
import 'internal_generate_docs.dart';
import 'ls_versions.dart';
import 'prefs.dart';
import 'pub.dart';
import 'repl.dart';
import 'run.dart';
import 'self_install.dart';
import 'self_uninstall.dart';
import 'self_upgrade.dart';
import 'version.dart';

/// Registers all commands on the given command runner.
void registerHavenCommands(HavenCommandRunner runner) {
  runner
    ..addCommand(VersionCommand())
    ..addCommand(EnvCreateCommand())
    ..addCommand(EnvUpgradeCommand())
    ..addCommand(EnvLsCommand())
    ..addCommand(EnvUseCommand())
    ..addCommand(CleanCommand())
    ..addCommand(EnvRmCommand())
    ..addCommand(EnvRenameCommand())
    ..addCommand(FlutterCommand())
    ..addCommand(DartCommand())
    ..addCommand(PubCommand())
    ..addCommand(RunCommand())
    ..addCommand(GenerateDocsCommand())
    ..addCommand(GenerateASTParserCommand())
    ..addCommand(SelfUpgradeCommand())
    ..addCommand(SelfInstallCommand())
    ..addCommand(SelfUninstallCommand())
    ..addCommand(GcCommand())
    ..addCommand(LsVersionsCommand())
    ..addCommand(EngineCommand())
    ..addCommand(PrefsCommand())
    ..addCommand(EvalCommand())
    ..addCommand(ReplCommand())
    ..addCommand(BuildShellCommand());
}
