import 'dart:async';
import 'dart:convert';

import 'package:file/file.dart';
import 'package:path/path.dart' as path;

import '../../models.dart';
import '../command_result.dart';
import '../extensions.dart';
import '../logger.dart';
import '../provider.dart';
import 'config.dart';
import 'prefs.dart';

class ProjectConfig {
  ProjectConfig({required this.projectDir, required this.parentProjectDir});

  late final HavenConfig parentConfig;
  final Directory? projectDir;
  final Directory? parentProjectDir;

  late final File? pubspecYamlFile = projectDir?.childFile('pubspec.yaml');
  late final File? havenDotfile = projectDir?.childFile(dotfileName);
  late final File? parentHavenDotfile = parentProjectDir?.childFile(dotfileName);

  static const dotfileName = '.haven.json';

  Directory ensureParentProjectDir() {
    final dir = parentProjectDir;
    if (dir == null) {
      throw CommandError(
        'Could not find a dart project in the current directory and no '
        'path selected with --project',
      );
    }
    return dir;
  }

  EnvConfig? tryGetProjectEnv() {
    if (parentHavenDotfile?.existsSync() != true) return null;
    final dotfile = readDotfile();
    if (!dotfile.hasEnv()) return null;
    final result = parentConfig.getEnv(dotfile.env);
    return result.exists ? result : null;
  }

  File get dotfileForWriting {
    if (!(projectDir?.path == parentProjectDir?.path)) {
      throw CommandError(
        'Found projects in both `${projectDir?.path}` and `${parentProjectDir?.path}`,'
        ' run this command in the parent directory or use `--project '
        '${path.relative(projectDir!.path, from: path.current)}'
        '` to switch regardless\n'
        "This check is done to make sure nested projects aren't using a different "
        'Flutter version as their parent',
      );
    }
    if (havenDotfile == null) ensureParentProjectDir();
    return havenDotfile!;
  }

  HavenDotfileModel readDotfile() {
    final model = HavenDotfileModel.create();
    if (parentHavenDotfile?.existsSync() ?? false) {
      final parsed =
          jsonDecode(parentHavenDotfile!.readAsStringSync()) as Map<String, dynamic>;
      validateJsonAgainstProto3Schema(parsed, HavenDotfileModel.create);
      model.mergeFromProto3Json(parsed);
    }
    return model;
  }

  HavenDotfileModel readDotfileForWriting() {
    final model = HavenDotfileModel.create();
    if (dotfileForWriting.existsSync()) {
      final parsed =
          jsonDecode(dotfileForWriting.readAsStringSync()) as Map<String, dynamic>;
      validateJsonAgainstProto3Schema(parsed, HavenDotfileModel.create);
      model.mergeFromProto3Json(parsed);
    }
    return model;
  }

  Future<void> writeDotfile(Scope scope, HavenDotfileModel dotfile) async {
    final log = HVLogger.of(scope);
    final file = dotfileForWriting;
    final jsonStr = const JsonEncoder.withIndent('  ').convert(dotfile.toProto3Json());
    log.d(() => 'Writing dotfile ${file.path}\n$jsonStr');
    file.writeAsStringSync(jsonStr);
    await registerDotfile(scope: scope, dotfile: file);
  }
}

Future<void> registerDotfile({required Scope scope, required File dotfile}) async {
  final prefs = await readGlobalPrefs(scope: scope);
  final canonical = dotfile.resolveIfExists().path;
  if (!prefs.projectDotfiles.contains(canonical)) {
    await updateGlobalPrefs(
      scope: scope,
      fn: (prefs) {
        prefs.projectDotfiles.add(canonical);
      },
    );
  }
}

Future<void> cleanDotfiles({required Scope scope}) {
  final config = HavenConfig.of(scope);
  return updateGlobalPrefs(
    scope: scope,
    fn: (prefs) {
      for (final path in prefs.projectDotfiles.toList()) {
        final canonical = config.fileSystem.file(path).resolveIfExists().path;
        if (config.fileSystem.statSync(path).type == FileSystemEntityType.notFound) {
          prefs.projectDotfiles.remove(path);
        } else if (canonical != path) {
          prefs.projectDotfiles.remove(path);
          prefs.projectDotfiles.add(canonical);
        }
      }
    },
  );
}

Future<Map<String, List<File>>> getAllDotfiles({required Scope scope}) async {
  final log = HVLogger.of(scope);
  final config = HavenConfig.of(scope);
  final prefs = await readGlobalPrefs(scope: scope);
  final result = <String, Set<String>>{};
  var needsClean = false;
  for (final path in prefs.projectDotfiles) {
    final dotfile = config.fileSystem.file(path);
    if (!dotfile.existsSync()) {
      needsClean = true;
      continue;
    }
    try {
      final data = jsonDecode(dotfile.readAsStringSync()) as Map<String, dynamic>;
      validateJsonAgainstProto3Schema(data, HavenDotfileModel.create);
      final model = HavenDotfileModel.create();
      model.mergeFromProto3Json(data);
      if (model.hasEnv()) {
        result.putIfAbsent(model.env, () => {}).add(dotfile.resolveSymbolicLinksSync());
      }
    } catch (exception, stackTrace) {
      log.w('Error while reading $path');
      log.w('$exception\n$stackTrace');
    }
  }
  log.d(() => 'all dotfiles: $result');
  if (needsClean) {
    await cleanDotfiles(scope: scope);
  }
  return result.map(
    (key, value) => MapEntry(key, value.map((e) => config.fileSystem.file(e)).toList()),
  );
}

Future<List<File>> getDotfilesUsingEnv({
  required Scope scope,
  required EnvConfig environment,
}) async {
  return (await getAllDotfiles(scope: scope))[environment.name] ?? [];
}
