import 'package:file/file.dart';
import 'package:protobuf/protobuf.dart';

/// Finds the closest parent directory containing a file with the given name.
Directory? findProjectDir(Directory directory, String fileName) {
  while (directory.existsSync()) {
    if (directory.fileSystem.statSync(directory.childFile(fileName).path).type !=
        FileSystemEntityType.notFound) {
      return directory;
    }
    final parent = directory.parent;
    if (directory.path == parent.path) break;
    directory = parent;
  }
  return null;
}

/// Validates a JSON map against a protobuf message schema.
/// Throws an exception if the JSON contains invalid fields or types.
void validateJsonAgainstProto3Schema<T extends GeneratedMessage>(
  Map<String, dynamic> json,
  T Function() createInstance,
) {
  final fieldInfo = createInstance().info_.fieldInfo;
  final validFields = <String, FieldInfo<dynamic>>{};
  for (final field in fieldInfo.values) {
    validFields[field.name] = field;
  }

  // Check for unknown fields
  for (final key in json.keys) {
    if (!validFields.containsKey(key)) {
      throw FormatException('Unknown field "$key" in JSON');
    }
  }

  // Check field types
  for (final entry in json.entries) {
    final key = entry.key;
    final value = entry.value;
    final field = validFields[key]!;

    if (!_isValidType(value, field)) {
      throw FormatException(
        'Invalid type for field "$key": expected ${_getExpectedTypeDescription(field)}, got ${value.runtimeType}',
      );
    }
  }
}

/// Checks if a value matches the expected protobuf field type.
bool _isValidType(dynamic value, FieldInfo<dynamic> field) {
  final type = field.type;
  final isRepeated = field.isRepeated;

  if (isRepeated) {
    if (value is! List) return false;
    // For repeated fields, check each element
    for (final item in value) {
      if (!_isValidScalarType(item, type)) return false;
    }
    return true;
  } else {
    return _isValidScalarType(value, type);
  }
}

/// Checks if a scalar value matches the expected protobuf type.
bool _isValidScalarType(dynamic value, int type) {
  switch (type) {
    case PbFieldType.OS: // optional string
    case PbFieldType.QS: // required string
      return value is String;
    case PbFieldType.OB: // optional bool
    case PbFieldType.QB: // required bool
      return value is bool;
    case PbFieldType.O3: // optional int32
    case PbFieldType.Q3: // required int32
    case PbFieldType.O6: // optional int64
    case PbFieldType.Q6: // required int64
      return value is int;
    default:
      // For other types, allow any value (they will be validated by protobuf merge)
      return true;
  }
}

/// Gets a human-readable description of the expected type for a field.
String _getExpectedTypeDescription(FieldInfo<dynamic> field) {
  final type = field.type;
  final isRepeated = field.isRepeated;

  String typeDesc;
  switch (type) {
    case PbFieldType.OS:
    case PbFieldType.QS:
      typeDesc = 'String';
      break;
    case PbFieldType.OB:
    case PbFieldType.QB:
      typeDesc = 'bool';
      break;
    case PbFieldType.O3:
    case PbFieldType.Q3:
    case PbFieldType.O6:
    case PbFieldType.Q6:
      typeDesc = 'int';
      break;
    default:
      typeDesc = 'unknown';
  }

  return isRepeated ? 'List<$typeDesc>' : typeDesc;
}
