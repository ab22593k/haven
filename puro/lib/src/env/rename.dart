import 'dart:convert';

import 'package:file/file.dart';

import '../../models.dart';
import '../command_result.dart';
import '../config/config.dart';
import '../config/project.dart';
import '../logger.dart';
import '../progress.dart';
import '../provider.dart';
import '../terminal.dart';
import '../workspace/install.dart';
import 'default.dart';
import 'transaction.dart';

/// Renames an environment.
Future<void> renameEnvironment({
  required Scope scope,
  required String name,
  required String newName,
}) async {
  final config = PuroConfig.of(scope);
  final env = config.getEnv(name);
  final log = PuroLogger.of(scope);
  env.ensureExists();
  final newEnv = config.getEnv(newName);

  if (newEnv.exists) {
    throw CommandError(
      'Environment `$newName` already exists',
    );
  } else if (env.name == newEnv.name) {
    throw CommandError(
      'Environment `$name` is already named `$newName`',
    );
  } else if (isPseudoEnvName(newName)) {
    throw CommandError(
      'Environment `$newName` is already pinned to a version, use `puro create $newName` to create it',
    );
  }

  final dotfiles = await getDotfilesUsingEnv(
    scope: scope,
    environment: env,
  );

  await EnvTransaction.run(
      scope: scope,
      body: (tx) async {
        // Delete lock file
        final lockExisted = env.updateLockFile.existsSync();
        await tx.step(
          label: 'delete update lock file',
          action: () async {
            if (lockExisted) {
              await env.updateLockFile.delete();
            }
          },
          rollback: () async {
            if (lockExisted && !env.updateLockFile.existsSync()) {
              await env.updateLockFile.create(recursive: true);
            }
          },
        );

        // Rename env directory
        await tx.step(
          label: 'rename environment directory',
          action: () async => env.envDir.renameSync(newEnv.envDir.path),
          rollback: () async => newEnv.envDir.renameSync(env.envDir.path),
        );

        // Update dotfiles
        final updatedDotfiles = <File>[];
        final originalContents = <File, String>{};
        await tx.step(
          label: 'update project dotfiles',
          action: () async {
            await ProgressNode.of(scope).wrap((scope, node) async {
              node.description = 'Updating projects';
              for (final dotfile in dotfiles) {
                try {
                  final projectConfig = ProjectConfig(
                    projectDir: dotfile.parent,
                    parentProjectDir: dotfile.parent,
                  );
                  projectConfig.parentConfig = config;
                  await switchEnvironment(
                    scope: scope,
                    envName: newName,
                    projectConfig: projectConfig,
                    passive: true,
                  );
                  updatedDotfiles.add(dotfile);
                } catch (exception, stackTrace) {
                  log.e('Exception while switching environment of ${dotfile.parent}');
                  log.e('$exception\n$stackTrace');
                }
                final data = jsonDecode(dotfile.readAsStringSync());
                originalContents[dotfile] = prettyJsonEncoder.convert(data);
                final model = PuroDotfileModel.create();
                model.mergeFromProto3Json(data);
                model.env = newName;
                dotfile
                    .writeAsStringSync(prettyJsonEncoder.convert(model.toProto3Json()));
              }
            });
          },
          rollback: () async {
            // Revert dotfiles
            for (final dotfile in updatedDotfiles) {
              if (originalContents.containsKey(dotfile)) {
                dotfile.writeAsStringSync(originalContents[dotfile]!);
              }
            }
            // Also revert the env name in dotfiles
            for (final dotfile in dotfiles) {
              if (dotfile.existsSync()) {
                final data = jsonDecode(dotfile.readAsStringSync());
                final model = PuroDotfileModel.create();
                model.mergeFromProto3Json(data);
                model.env = name; // back to old name
                dotfile
                    .writeAsStringSync(prettyJsonEncoder.convert(model.toProto3Json()));
              }
            }
          },
        );

        if (dotfiles.isNotEmpty) {
          CommandMessage(
            'Updated the following projects:\n'
            '${dotfiles.map((p) => '* ${p.parent.path}').join('\n')}',
            type: CompletionType.info,
          ).queue(scope);
        }
      });
}
