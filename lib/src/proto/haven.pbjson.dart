// This is a generated file - do not edit.
//
// Generated from haven.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, unused_import

import 'dart:convert' as $convert;
import 'dart:core' as $core;
import 'dart:typed_data' as $typed_data;

@$core.Deprecated('Use commandErrorModelDescriptor instead')
const CommandErrorModel$json = {
  '1': 'CommandErrorModel',
  '2': [
    {'1': 'exception', '3': 1, '4': 1, '5': 9, '10': 'exception'},
    {'1': 'exceptionType', '3': 2, '4': 1, '5': 9, '10': 'exceptionType'},
    {'1': 'stackTrace', '3': 3, '4': 1, '5': 9, '10': 'stackTrace'},
  ],
};

/// Descriptor for `CommandErrorModel`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List commandErrorModelDescriptor = $convert.base64Decode(
    'ChFDb21tYW5kRXJyb3JNb2RlbBIcCglleGNlcHRpb24YASABKAlSCWV4Y2VwdGlvbhIkCg1leG'
    'NlcHRpb25UeXBlGAIgASgJUg1leGNlcHRpb25UeXBlEh4KCnN0YWNrVHJhY2UYAyABKAlSCnN0'
    'YWNrVHJhY2U=');

@$core.Deprecated('Use logEntryModelDescriptor instead')
const LogEntryModel$json = {
  '1': 'LogEntryModel',
  '2': [
    {'1': 'timestamp', '3': 1, '4': 1, '5': 9, '10': 'timestamp'},
    {'1': 'level', '3': 2, '4': 1, '5': 5, '10': 'level'},
    {'1': 'message', '3': 3, '4': 1, '5': 9, '10': 'message'},
  ],
};

/// Descriptor for `LogEntryModel`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List logEntryModelDescriptor = $convert.base64Decode(
    'Cg1Mb2dFbnRyeU1vZGVsEhwKCXRpbWVzdGFtcBgBIAEoCVIJdGltZXN0YW1wEhQKBWxldmVsGA'
    'IgASgFUgVsZXZlbBIYCgdtZXNzYWdlGAMgASgJUgdtZXNzYWdl');

@$core.Deprecated('Use flutterVersionModelDescriptor instead')
const FlutterVersionModel$json = {
  '1': 'FlutterVersionModel',
  '2': [
    {'1': 'commit', '3': 1, '4': 1, '5': 9, '10': 'commit'},
    {'1': 'version', '3': 2, '4': 1, '5': 9, '9': 0, '10': 'version', '17': true},
    {'1': 'branch', '3': 3, '4': 1, '5': 9, '9': 1, '10': 'branch', '17': true},
    {'1': 'tag', '3': 4, '4': 1, '5': 9, '9': 2, '10': 'tag', '17': true},
  ],
  '8': [
    {'1': '_version'},
    {'1': '_branch'},
    {'1': '_tag'},
  ],
};

/// Descriptor for `FlutterVersionModel`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List flutterVersionModelDescriptor = $convert.base64Decode(
    'ChNGbHV0dGVyVmVyc2lvbk1vZGVsEhYKBmNvbW1pdBgBIAEoCVIGY29tbWl0Eh0KB3ZlcnNpb2'
    '4YAiABKAlIAFIHdmVyc2lvbogBARIbCgZicmFuY2gYAyABKAlIAVIGYnJhbmNoiAEBEhUKA3Rh'
    'ZxgEIAEoCUgCUgN0YWeIAQFCCgoIX3ZlcnNpb25CCQoHX2JyYW5jaEIGCgRfdGFn');

@$core.Deprecated('Use environmentInfoModelDescriptor instead')
const EnvironmentInfoModel$json = {
  '1': 'EnvironmentInfoModel',
  '2': [
    {'1': 'name', '3': 1, '4': 1, '5': 9, '10': 'name'},
    {'1': 'path', '3': 2, '4': 1, '5': 9, '10': 'path'},
    {
      '1': 'version',
      '3': 3,
      '4': 1,
      '5': 11,
      '6': '.FlutterVersionModel',
      '9': 0,
      '10': 'version',
      '17': true
    },
    {
      '1': 'dartVersion',
      '3': 5,
      '4': 1,
      '5': 9,
      '9': 1,
      '10': 'dartVersion',
      '17': true
    },
    {'1': 'projects', '3': 4, '4': 3, '5': 9, '10': 'projects'},
  ],
  '8': [
    {'1': '_version'},
    {'1': '_dartVersion'},
  ],
};

/// Descriptor for `EnvironmentInfoModel`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List environmentInfoModelDescriptor = $convert.base64Decode(
    'ChRFbnZpcm9ubWVudEluZm9Nb2RlbBISCgRuYW1lGAEgASgJUgRuYW1lEhIKBHBhdGgYAiABKA'
    'lSBHBhdGgSMwoHdmVyc2lvbhgDIAEoCzIULkZsdXR0ZXJWZXJzaW9uTW9kZWxIAFIHdmVyc2lv'
    'bogBARIlCgtkYXJ0VmVyc2lvbhgFIAEoCUgBUgtkYXJ0VmVyc2lvbogBARIaCghwcm9qZWN0cx'
    'gEIAMoCVIIcHJvamVjdHNCCgoIX3ZlcnNpb25CDgoMX2RhcnRWZXJzaW9u');

@$core.Deprecated('Use environmentListModelDescriptor instead')
const EnvironmentListModel$json = {
  '1': 'EnvironmentListModel',
  '2': [
    {
      '1': 'environments',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.EnvironmentInfoModel',
      '10': 'environments'
    },
    {
      '1': 'projectEnvironment',
      '3': 2,
      '4': 1,
      '5': 9,
      '9': 0,
      '10': 'projectEnvironment',
      '17': true
    },
    {
      '1': 'globalEnvironment',
      '3': 3,
      '4': 1,
      '5': 9,
      '9': 1,
      '10': 'globalEnvironment',
      '17': true
    },
  ],
  '8': [
    {'1': '_projectEnvironment'},
    {'1': '_globalEnvironment'},
  ],
};

/// Descriptor for `EnvironmentListModel`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List environmentListModelDescriptor = $convert.base64Decode(
    'ChRFbnZpcm9ubWVudExpc3RNb2RlbBI5CgxlbnZpcm9ubWVudHMYASADKAsyFS5FbnZpcm9ubW'
    'VudEluZm9Nb2RlbFIMZW52aXJvbm1lbnRzEjMKEnByb2plY3RFbnZpcm9ubWVudBgCIAEoCUgA'
    'UhJwcm9qZWN0RW52aXJvbm1lbnSIAQESMQoRZ2xvYmFsRW52aXJvbm1lbnQYAyABKAlIAVIRZ2'
    'xvYmFsRW52aXJvbm1lbnSIAQFCFQoTX3Byb2plY3RFbnZpcm9ubWVudEIUChJfZ2xvYmFsRW52'
    'aXJvbm1lbnQ=');

@$core.Deprecated('Use environmentUpgradeModelDescriptor instead')
const EnvironmentUpgradeModel$json = {
  '1': 'EnvironmentUpgradeModel',
  '2': [
    {'1': 'name', '3': 1, '4': 1, '5': 9, '10': 'name'},
    {'1': 'from', '3': 2, '4': 1, '5': 11, '6': '.FlutterVersionModel', '10': 'from'},
    {'1': 'to', '3': 3, '4': 1, '5': 11, '6': '.FlutterVersionModel', '10': 'to'},
  ],
};

/// Descriptor for `EnvironmentUpgradeModel`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List environmentUpgradeModelDescriptor = $convert.base64Decode(
    'ChdFbnZpcm9ubWVudFVwZ3JhZGVNb2RlbBISCgRuYW1lGAEgASgJUgRuYW1lEigKBGZyb20YAi'
    'ABKAsyFC5GbHV0dGVyVmVyc2lvbk1vZGVsUgRmcm9tEiQKAnRvGAMgASgLMhQuRmx1dHRlclZl'
    'cnNpb25Nb2RlbFICdG8=');

@$core.Deprecated('Use commandMessageModelDescriptor instead')
const CommandMessageModel$json = {
  '1': 'CommandMessageModel',
  '2': [
    {'1': 'type', '3': 1, '4': 1, '5': 9, '10': 'type'},
    {'1': 'message', '3': 2, '4': 1, '5': 9, '10': 'message'},
  ],
};

/// Descriptor for `CommandMessageModel`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List commandMessageModelDescriptor = $convert.base64Decode(
    'ChNDb21tYW5kTWVzc2FnZU1vZGVsEhIKBHR5cGUYASABKAlSBHR5cGUSGAoHbWVzc2FnZRgCIA'
    'EoCVIHbWVzc2FnZQ==');

@$core.Deprecated('Use commandResultModelDescriptor instead')
const CommandResultModel$json = {
  '1': 'CommandResultModel',
  '2': [
    {'1': 'success', '3': 1, '4': 1, '5': 8, '10': 'success'},
    {
      '1': 'messages',
      '3': 2,
      '4': 3,
      '5': 11,
      '6': '.CommandMessageModel',
      '10': 'messages'
    },
    {'1': 'usage', '3': 3, '4': 1, '5': 9, '9': 0, '10': 'usage', '17': true},
    {
      '1': 'error',
      '3': 4,
      '4': 1,
      '5': 11,
      '6': '.CommandErrorModel',
      '9': 1,
      '10': 'error',
      '17': true
    },
    {'1': 'logs', '3': 5, '4': 3, '5': 11, '6': '.LogEntryModel', '10': 'logs'},
    {
      '1': 'environmentList',
      '3': 6,
      '4': 1,
      '5': 11,
      '6': '.EnvironmentListModel',
      '9': 2,
      '10': 'environmentList',
      '17': true
    },
    {
      '1': 'environmentUpgrade',
      '3': 7,
      '4': 1,
      '5': 11,
      '6': '.EnvironmentUpgradeModel',
      '9': 3,
      '10': 'environmentUpgrade',
      '17': true
    },
  ],
  '8': [
    {'1': '_usage'},
    {'1': '_error'},
    {'1': '_environmentList'},
    {'1': '_environmentUpgrade'},
  ],
};

/// Descriptor for `CommandResultModel`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List commandResultModelDescriptor = $convert.base64Decode(
    'ChJDb21tYW5kUmVzdWx0TW9kZWwSGAoHc3VjY2VzcxgBIAEoCFIHc3VjY2VzcxIwCghtZXNzYW'
    'dlcxgCIAMoCzIULkNvbW1hbmRNZXNzYWdlTW9kZWxSCG1lc3NhZ2VzEhkKBXVzYWdlGAMgASgJ'
    'SABSBXVzYWdliAEBEi0KBWVycm9yGAQgASgLMhIuQ29tbWFuZEVycm9yTW9kZWxIAVIFZXJyb3'
    'KIAQESIgoEbG9ncxgFIAMoCzIOLkxvZ0VudHJ5TW9kZWxSBGxvZ3MSRAoPZW52aXJvbm1lbnRM'
    'aXN0GAYgASgLMhUuRW52aXJvbm1lbnRMaXN0TW9kZWxIAlIPZW52aXJvbm1lbnRMaXN0iAEBEk'
    '0KEmVudmlyb25tZW50VXBncmFkZRgHIAEoCzIYLkVudmlyb25tZW50VXBncmFkZU1vZGVsSANS'
    'EmVudmlyb25tZW50VXBncmFkZYgBAUIICgZfdXNhZ2VCCAoGX2Vycm9yQhIKEF9lbnZpcm9ubW'
    'VudExpc3RCFQoTX2Vudmlyb25tZW50VXBncmFkZQ==');

@$core.Deprecated('Use havenGlobalPrefsModelDescriptor instead')
const HavenGlobalPrefsModel$json = {
  '1': 'HavenGlobalPrefsModel',
  '2': [
    {
      '1': 'defaultEnvironment',
      '3': 1,
      '4': 1,
      '5': 9,
      '9': 0,
      '10': 'defaultEnvironment',
      '17': true
    },
    {
      '1': 'lastUpdateCheck',
      '3': 2,
      '4': 1,
      '5': 9,
      '9': 1,
      '10': 'lastUpdateCheck',
      '17': true
    },
    {
      '1': 'lastUpdateNotification',
      '3': 3,
      '4': 1,
      '5': 9,
      '9': 2,
      '10': 'lastUpdateNotification',
      '17': true
    },
    {
      '1': 'lastUpdateNotificationCommand',
      '3': 8,
      '4': 1,
      '5': 9,
      '9': 3,
      '10': 'lastUpdateNotificationCommand',
      '17': true
    },
    {
      '1': 'enableUpdateCheck',
      '3': 4,
      '4': 1,
      '5': 8,
      '9': 4,
      '10': 'enableUpdateCheck',
      '17': true
    },
    {
      '1': 'enableProfileUpdate',
      '3': 5,
      '4': 1,
      '5': 8,
      '9': 5,
      '10': 'enableProfileUpdate',
      '17': true
    },
    {
      '1': 'profileOverride',
      '3': 6,
      '4': 1,
      '5': 9,
      '9': 6,
      '10': 'profileOverride',
      '17': true
    },
    {'1': 'projectDotfiles', '3': 7, '4': 3, '5': 9, '10': 'projectDotfiles'},
    {
      '1': 'pubCacheDir',
      '3': 9,
      '4': 1,
      '5': 9,
      '9': 7,
      '10': 'pubCacheDir',
      '17': true
    },
    {
      '1': 'flutterGitUrl',
      '3': 10,
      '4': 1,
      '5': 9,
      '9': 8,
      '10': 'flutterGitUrl',
      '17': true
    },
    {
      '1': 'engineGitUrl',
      '3': 11,
      '4': 1,
      '5': 9,
      '9': 9,
      '10': 'engineGitUrl',
      '17': true
    },
    {
      '1': 'dartSdkGitUrl',
      '3': 12,
      '4': 1,
      '5': 9,
      '9': 10,
      '10': 'dartSdkGitUrl',
      '17': true
    },
    {
      '1': 'releasesJsonUrl',
      '3': 13,
      '4': 1,
      '5': 9,
      '9': 11,
      '10': 'releasesJsonUrl',
      '17': true
    },
    {
      '1': 'flutterStorageBaseUrl',
      '3': 14,
      '4': 1,
      '5': 9,
      '9': 12,
      '10': 'flutterStorageBaseUrl',
      '17': true
    },
    {
      '1': 'shouldInstall',
      '3': 18,
      '4': 1,
      '5': 8,
      '9': 13,
      '10': 'shouldInstall',
      '17': true
    },
    {
      '1': 'legacyPubCache',
      '3': 19,
      '4': 1,
      '5': 8,
      '9': 14,
      '10': 'legacyPubCache',
      '17': true
    },
  ],
  '8': [
    {'1': '_defaultEnvironment'},
    {'1': '_lastUpdateCheck'},
    {'1': '_lastUpdateNotification'},
    {'1': '_lastUpdateNotificationCommand'},
    {'1': '_enableUpdateCheck'},
    {'1': '_enableProfileUpdate'},
    {'1': '_profileOverride'},
    {'1': '_pubCacheDir'},
    {'1': '_flutterGitUrl'},
    {'1': '_engineGitUrl'},
    {'1': '_dartSdkGitUrl'},
    {'1': '_releasesJsonUrl'},
    {'1': '_flutterStorageBaseUrl'},
    {'1': '_shouldInstall'},
    {'1': '_legacyPubCache'},
  ],
};

/// Descriptor for `HavenGlobalPrefsModel`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List havenGlobalPrefsModelDescriptor = $convert.base64Decode(
    'ChVIYXZlbkdsb2JhbFByZWZzTW9kZWwSMwoSZGVmYXVsdEVudmlyb25tZW50GAEgASgJSABSEm'
    'RlZmF1bHRFbnZpcm9ubWVudIgBARItCg9sYXN0VXBkYXRlQ2hlY2sYAiABKAlIAVIPbGFzdFVw'
    'ZGF0ZUNoZWNriAEBEjsKFmxhc3RVcGRhdGVOb3RpZmljYXRpb24YAyABKAlIAlIWbGFzdFVwZG'
    'F0ZU5vdGlmaWNhdGlvbogBARJJCh1sYXN0VXBkYXRlTm90aWZpY2F0aW9uQ29tbWFuZBgIIAEo'
    'CUgDUh1sYXN0VXBkYXRlTm90aWZpY2F0aW9uQ29tbWFuZIgBARIxChFlbmFibGVVcGRhdGVDaG'
    'VjaxgEIAEoCEgEUhFlbmFibGVVcGRhdGVDaGVja4gBARI1ChNlbmFibGVQcm9maWxlVXBkYXRl'
    'GAUgASgISAVSE2VuYWJsZVByb2ZpbGVVcGRhdGWIAQESLQoPcHJvZmlsZU92ZXJyaWRlGAYgAS'
    'gJSAZSD3Byb2ZpbGVPdmVycmlkZYgBARIoCg9wcm9qZWN0RG90ZmlsZXMYByADKAlSD3Byb2pl'
    'Y3REb3RmaWxlcxIlCgtwdWJDYWNoZURpchgJIAEoCUgHUgtwdWJDYWNoZURpcogBARIpCg1mbH'
    'V0dGVyR2l0VXJsGAogASgJSAhSDWZsdXR0ZXJHaXRVcmyIAQESJwoMZW5naW5lR2l0VXJsGAsg'
    'ASgJSAlSDGVuZ2luZUdpdFVybIgBARIpCg1kYXJ0U2RrR2l0VXJsGAwgASgJSApSDWRhcnRTZG'
    'tHaXRVcmyIAQESLQoPcmVsZWFzZXNKc29uVXJsGA0gASgJSAtSD3JlbGVhc2VzSnNvblVybIgB'
    'ARI5ChVmbHV0dGVyU3RvcmFnZUJhc2VVcmwYDiABKAlIDFIVZmx1dHRlclN0b3JhZ2VCYXNlVX'
    'JsiAEBEikKDXNob3VsZEluc3RhbGwYEiABKAhIDVINc2hvdWxkSW5zdGFsbIgBARIrCg5sZWdh'
    'Y3lQdWJDYWNoZRgTIAEoCEgOUg5sZWdhY3lQdWJDYWNoZYgBAUIVChNfZGVmYXVsdEVudmlyb2'
    '5tZW50QhIKEF9sYXN0VXBkYXRlQ2hlY2tCGQoXX2xhc3RVcGRhdGVOb3RpZmljYXRpb25CIAoe'
    'X2xhc3RVcGRhdGVOb3RpZmljYXRpb25Db21tYW5kQhQKEl9lbmFibGVVcGRhdGVDaGVja0IWCh'
    'RfZW5hYmxlUHJvZmlsZVVwZGF0ZUISChBfcHJvZmlsZU92ZXJyaWRlQg4KDF9wdWJDYWNoZURp'
    'ckIQCg5fZmx1dHRlckdpdFVybEIPCg1fZW5naW5lR2l0VXJsQhAKDl9kYXJ0U2RrR2l0VXJsQh'
    'IKEF9yZWxlYXNlc0pzb25VcmxCGAoWX2ZsdXR0ZXJTdG9yYWdlQmFzZVVybEIQCg5fc2hvdWxk'
    'SW5zdGFsbEIRCg9fbGVnYWN5UHViQ2FjaGU=');

@$core.Deprecated('Use havenEnvPrefsModelDescriptor instead')
const HavenEnvPrefsModel$json = {
  '1': 'HavenEnvPrefsModel',
  '2': [
    {
      '1': 'desiredVersion',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.FlutterVersionModel',
      '9': 0,
      '10': 'desiredVersion',
      '17': true
    },
    {
      '1': 'forkRemoteUrl',
      '3': 2,
      '4': 1,
      '5': 9,
      '9': 1,
      '10': 'forkRemoteUrl',
      '17': true
    },
    {
      '1': 'engineForkRemoteUrl',
      '3': 3,
      '4': 1,
      '5': 9,
      '9': 2,
      '10': 'engineForkRemoteUrl',
      '17': true
    },
    {
      '1': 'precompileTool',
      '3': 4,
      '4': 1,
      '5': 8,
      '9': 3,
      '10': 'precompileTool',
      '17': true
    },
    {'1': 'patched', '3': 5, '4': 1, '5': 8, '9': 4, '10': 'patched', '17': true},
  ],
  '8': [
    {'1': '_desiredVersion'},
    {'1': '_forkRemoteUrl'},
    {'1': '_engineForkRemoteUrl'},
    {'1': '_precompileTool'},
    {'1': '_patched'},
  ],
};

/// Descriptor for `HavenEnvPrefsModel`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List havenEnvPrefsModelDescriptor = $convert.base64Decode(
    'ChJIYXZlbkVudlByZWZzTW9kZWwSQQoOZGVzaXJlZFZlcnNpb24YASABKAsyFC5GbHV0dGVyVm'
    'Vyc2lvbk1vZGVsSABSDmRlc2lyZWRWZXJzaW9uiAEBEikKDWZvcmtSZW1vdGVVcmwYAiABKAlI'
    'AVINZm9ya1JlbW90ZVVybIgBARI1ChNlbmdpbmVGb3JrUmVtb3RlVXJsGAMgASgJSAJSE2VuZ2'
    'luZUZvcmtSZW1vdGVVcmyIAQESKwoOcHJlY29tcGlsZVRvb2wYBCABKAhIA1IOcHJlY29tcGls'
    'ZVRvb2yIAQESHQoHcGF0Y2hlZBgFIAEoCEgEUgdwYXRjaGVkiAEBQhEKD19kZXNpcmVkVmVyc2'
    'lvbkIQCg5fZm9ya1JlbW90ZVVybEIWChRfZW5naW5lRm9ya1JlbW90ZVVybEIRCg9fcHJlY29t'
    'cGlsZVRvb2xCCgoIX3BhdGNoZWQ=');

@$core.Deprecated('Use havenDotfileModelDescriptor instead')
const HavenDotfileModel$json = {
  '1': 'HavenDotfileModel',
  '2': [
    {'1': 'env', '3': 1, '4': 1, '5': 9, '9': 0, '10': 'env', '17': true},
    {
      '1': 'previousDartSdk',
      '3': 2,
      '4': 1,
      '5': 9,
      '9': 1,
      '10': 'previousDartSdk',
      '17': true
    },
    {
      '1': 'previousFlutterSdk',
      '3': 3,
      '4': 1,
      '5': 9,
      '9': 2,
      '10': 'previousFlutterSdk',
      '17': true
    },
  ],
  '8': [
    {'1': '_env'},
    {'1': '_previousDartSdk'},
    {'1': '_previousFlutterSdk'},
  ],
};

/// Descriptor for `HavenDotfileModel`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List havenDotfileModelDescriptor = $convert.base64Decode(
    'ChFIYXZlbkRvdGZpbGVNb2RlbBIVCgNlbnYYASABKAlIAFIDZW52iAEBEi0KD3ByZXZpb3VzRG'
    'FydFNkaxgCIAEoCUgBUg9wcmV2aW91c0RhcnRTZGuIAQESMwoScHJldmlvdXNGbHV0dGVyU2Rr'
    'GAMgASgJSAJSEnByZXZpb3VzRmx1dHRlclNka4gBAUIGCgRfZW52QhIKEF9wcmV2aW91c0Rhcn'
    'RTZGtCFQoTX3ByZXZpb3VzRmx1dHRlclNkaw==');
