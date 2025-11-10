import 'dart:async';
import 'dart:convert';

import 'package:file/file.dart';
import 'package:protobuf/protobuf.dart';

import '../../models.dart';
import '../file_lock.dart';
import '../logger.dart';
import '../provider.dart';
import 'config.dart';

class GlobalPrefsConfig {
  GlobalPrefsConfig({
    required this.jsonFile,
    required this.flutterGitUrl,
    required this.engineGitUrl,
    required this.dartSdkGitUrl,
    required this.releasesJsonUrl,
    required this.flutterStorageBaseUrl,
    required this.puroBuildsUrl,
    required this.puroBuildTarget,
    required this.pubCacheDir,
    required this.shouldInstall,
  });

  final File jsonFile;
  final String? flutterGitUrl;
  final String? engineGitUrl;
  final String? dartSdkGitUrl;
  final String? releasesJsonUrl;
  final String? flutterStorageBaseUrl;
  final String? puroBuildsUrl;
  final String? puroBuildTarget;
  final String? pubCacheDir;
  final bool? shouldInstall;

  static Future<GlobalPrefsConfig> load({
    required Scope scope,
    required File jsonFile,
  }) async {
    final model = await _readGlobalPrefs(scope: scope, jsonFile: jsonFile);
    return GlobalPrefsConfig(
      jsonFile: jsonFile,
      flutterGitUrl: model.hasFlutterGitUrl() ? model.flutterGitUrl : null,
      engineGitUrl: model.hasEngineGitUrl() ? model.engineGitUrl : null,
      dartSdkGitUrl: model.hasDartSdkGitUrl() ? model.dartSdkGitUrl : null,
      releasesJsonUrl: model.hasReleasesJsonUrl() ? model.releasesJsonUrl : null,
      flutterStorageBaseUrl:
          model.hasFlutterStorageBaseUrl() ? model.flutterStorageBaseUrl : null,
      puroBuildsUrl: model.hasPuroBuildsUrl() ? model.puroBuildsUrl : null,
      puroBuildTarget: model.hasPuroBuildTarget() ? model.puroBuildTarget : null,
      pubCacheDir: model.hasPubCacheDir() ? model.pubCacheDir : null,
      shouldInstall: model.hasShouldInstall() ? model.shouldInstall : null,
    );
  }

  Future<void> update(
      Scope scope, FutureOr<void> Function(PuroGlobalPrefsModel prefs) fn) async {
    await _updateGlobalPrefs(scope: scope, jsonFile: jsonFile, fn: fn);
  }
}

Future<PuroGlobalPrefsModel> _readGlobalPrefs({
  required Scope scope,
  required File jsonFile,
}) async {
  final model = PuroGlobalPrefsModel();
  if (jsonFile.existsSync()) {
    final contents = await readAtomic(scope: scope, file: jsonFile);
    model.mergeFromProto3Json(jsonDecode(contents));
  }
  return model;
}

Future<PuroGlobalPrefsModel> _updateGlobalPrefs({
  required Scope scope,
  required File jsonFile,
  required FutureOr<void> Function(PuroGlobalPrefsModel prefs) fn,
  bool background = false,
}) {
  jsonFile.parent.createSync(recursive: true);
  return lockFile(
    scope,
    jsonFile,
    (handle) async {
       final model = PuroGlobalPrefsModel();
       String? contents;
       if (handle.lengthSync() > 0) {
         contents = utf8.decode(handle.readSync(handle.lengthSync()));
         try {
           model.mergeFromProto3Json(jsonDecode(contents));
         } catch (e) {
           // If JSON is corrupted, start with empty model
           scope.read(PuroLogger.provider).w('Failed to parse prefs.json, starting with empty prefs: $e');
         }
       }
      await fn(model);
      if (!model.hasLegacyPubCache()) {
        model.legacyPubCache = !scope.read(isFirstRunProvider);
      }
      final newContents =
          const JsonEncoder.withIndent('  ').convert(model.toProto3Json());
      if (contents != newContents) {
        handle.writeStringSync(newContents);
      }
      return model;
    },
    mode: FileMode.append,
  );
}

final globalPrefsJsonFileProvider = Provider<File>.late();
final isFirstRunProvider = Provider<bool>.late();
final globalPrefsProvider = Provider<Future<PuroGlobalPrefsModel>>(
  (scope) =>
      _readGlobalPrefs(scope: scope, jsonFile: scope.read(globalPrefsJsonFileProvider)),
);

Future<PuroGlobalPrefsModel> readGlobalPrefs({
  required Scope scope,
}) {
  return scope.read(globalPrefsProvider);
}

Future<PuroGlobalPrefsModel> updateGlobalPrefs({
  required Scope scope,
  required FutureOr<void> Function(PuroGlobalPrefsModel prefs) fn,
  bool background = false,
}) async {
  await scope.read(globalPrefsProvider);
  final result = await _updateGlobalPrefs(
    scope: scope,
    jsonFile: scope.read(globalPrefsJsonFileProvider),
    fn: fn,
    background: background,
  );
  scope.replace(globalPrefsProvider, Future.value(result));
  return result;
}

class PuroInternalPrefsVars {
  PuroInternalPrefsVars({required this.scope, required this.config});

  final Scope scope;
  final PuroConfig config;
  PuroGlobalPrefsModel? prefs;

  static final _fieldInfo = PuroGlobalPrefsModel.getDefault().info_.fieldInfo;
  static final _fields = {
    for (final field in _fieldInfo.values) field.name: field,
  };

  Future<dynamic> readVar(String key) async {
    if (!_fields.containsKey(key)) {
      throw 'No such key ${jsonEncode(key)}, valid keys: ${_fields.keys.toList()}';
    }
    prefs ??= await readGlobalPrefs(scope: scope);
    final data = prefs!.toProto3Json() as Map<String, dynamic>;
    return data[key];
  }

  Future<void> writeVar(String key, String value) async {
    final field = _fields[key];
    if (field == null) {
      throw 'No such key ${jsonEncode(key)}, valid keys: ${_fields.keys.toList()}';
    }
    await updateGlobalPrefs(
      scope: scope,
      fn: (prefs) {
        final data = prefs.toProto3Json() as Map<String, dynamic>;

        if (value == 'null') {
          data.remove(key);
        } else {
          // If the field is a string, and the value does not start with ", just use
          // that literal value, otherwise we interpret it as json.
          if (field.type & PbFieldType.OS == PbFieldType.OS && !value.startsWith('"')) {
            data[key] = value;
          } else {
            data[key] = jsonDecode(value);
          }
          prefs = prefs;
        }

        prefs.clear();
        prefs.mergeFromProto3Json(data);
      },
    );
  }
}
