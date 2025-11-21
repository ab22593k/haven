import 'ast_types.dart';

String generateAstForSchemas(Map<int, dynamic> schemas, {String? comment}) {
  String fixName(String name, {bool lower = false}) {
    var out =
        const {
          'VariableDeclarationPlain': 'VariableDeclaration',
          'class': 'clazz',
          '8bitAlignment': 'byteAlignment',
          'Deprecated_ConstantExpression': 'ConstantExpression',
          'IsLoweredLateField': 'isLoweredLateField',
        }[name] ??
        name;
    if (lower) {
      out = out[0].toLowerCase() + out.substring(1);
    }
    return out;
  }

  final types = <String, DartType>{
    'Byte': RawType('int'),
    'UInt': RawType('int'),
    'UInt7': RawType('int'),
    'UInt14': RawType('int'),
    'UInt30': RawType('int'),
    'UInt32': RawType('int'),
    'Double': RawType('double'),
    'StringReference': RawType('String'),
    'ConstantReference': RawType('Constant'),
    'CanonicalNameReference': RawType('CanonicalName?'),
    'UriReference': RawType('Uri'),
    'FileOffset': RawType('int'),
    'String': RawType('String'),
  };

  DartType getType(dynamic data) {
    if (data is String) {
      return types[fixName(data)] ?? (throw AssertionError('Unknown type $data'));
    } else if (data['list'] != null) {
      return ListType()..element = getType(data['list']);
    } else if (data['rlist'] != null) {
      return ListType()..element = getType(data['rlist']);
    } else if (data['option'] != null) {
      return OptionType()..element = getType(data['option']);
    } else if (data['ifPrivate'] != null) {
      return OptionType()..element = getType(data['ifPrivate']);
    } else if (data['pair'] != null) {
      return PairType()
        ..first = getType(data['pair'][0])
        ..second = getType(data['pair'][1]);
    } else if (data['union'] != null) {
      return UnionType()
        ..first = getType(data['union'][0])
        ..second = getType(data['union'][1]);
    } else if (data['array'] != null) {
      return ListType()..element = getType(data['array'][0]);
    } else {
      throw AssertionError('Unknown type $data');
    }
  }

  DartType resolveMerge(DartType from, DartType to) {
    final result = const {
      ('Expression', 'IntegerLiteral'): 'IntegerLiteral',
      (
        'PositiveIntLiteral | NegativeIntLiteral | SpecializedIntLiteral | BigIntLiteral',
        'IntegerLiteral',
      ): 'IntegerLiteral',
    }[(from.name, to.name)];
    if (result != null) {
      return getType(result);
    } else {
      throw AssertionError('Mismatch ${from.name} != ${to.name}');
    }
  }

  const skipTypes = {'StringTable', 'FileOffset'};

  for (final entry in schemas.entries) {
    for (final decl in entry.value as List) {
      if (decl['type'] != null) {
        final isAbstract = decl['type'][0] as bool;
        final name = fixName(decl['type'][1] as String);
        if (skipTypes.contains(name)) continue;
        final existing = types[name];
        if (existing is RawType) continue;
        if (existing == null) {
          types[name] = ClassType()
            ..name = name
            ..abstract = isAbstract;
        } else {
          final type = existing as ClassType;
          if (type.abstract != isAbstract) {
            throw AssertionError(
              'Abstract mismatch for $name: ${type.abstract} != $isAbstract',
            );
          }
        }
      } else if (decl['enum'] != null) {
        final type = EnumType();
        type.name = fixName(decl['enum'][0] as String);
        for (final value in decl['enum'][1] as List) {
          type.values.add(fixName(value[0] as String, lower: true));
        }
        types[type.name] = type;
      } else {
        throw AssertionError('Unknown declaration $decl');
      }
    }
  }

  // Second pass, fill in fields
  for (final entry in schemas.entries) {
    for (final decl in entry.value as List) {
      if (decl['type'] != null) {
        final name = fixName(decl['type'][1] as String);
        if (types[name] is RawType || skipTypes.contains(name)) continue;
        var parent = decl['type'][2] as String?;
        if (parent == 'TreeNode') {
          parent = null; // Not actually defined
        }
        final fields = decl['type'][3] as List;
        final dartFields = <String, DartType>{};
        for (final field in fields) {
          if (field['field'] != null) {
            final hasDefault = field['field'][2] != null;
            final fieldName = fixName(field['field'][1] as String);
            if (hasDefault ||
                fieldName == 'tag' ||
                fieldName == '_unused_' ||
                fieldName == '8bitAlignment' ||
                (name == 'ComponentFile' &&
                    (fieldName == 'constants' || fieldName == 'strings'))) {
              continue;
            }
            final type = getType(field['field'][0]);
            dartFields[fieldName] = type;
          } else if (field['bitfield'] != null) {
            final names = field['bitfield'][2] as List;
            for (final name in names) {
              if (name == '_unused_') continue;
              dartFields[fixName(name as String)] = RawType('bool');
            }
          } else {
            throw AssertionError('Unknown field $field');
          }
        }
        final existing = types[name] as ClassType;
        if (parent != null) {
          final parentType = getType(parent) as ClassType;
          final existingParentName = existing.parent?.name;
          final parentName = parentType.name;

          if (existingParentName != null && existingParentName != parentName) {
            existing.parent = resolveMerge(existing.parent!, parentType) as ClassType;
          } else {
            existing.parent = parentType;
          }
        }
        for (final entry in dartFields.entries) {
          final existingField = existing.fields[entry.key];
          if (existingField == null) {
            existing.fields[entry.key] = entry.value;
          } else {
            existing.fields[entry.key] = existingField.merge(entry.value);
          }
        }
      }
    }
  }

  final outAst = StringBuffer();

  if (comment != null) {
    outAst.writeln(comment.split('\n').map((e) => '// $e').join('\n') + '\n');
  }

  for (final tpe in types.values) {
    if (tpe is ClassType) {
      if (tpe.abstract) {
        outAst.write('abstract ');
      }
      outAst.write('class ${tpe.name}');
      if (tpe.parent != null) {
        outAst.write(' extends ${tpe.parent!.name}');
      }
      outAst.writeln(' {');
      if (!tpe.abstract && tpe.fields.isNotEmpty) {
        outAst.writeln('  ${tpe.name}({');
        for (final field in tpe.fields.entries) {
          outAst.write('    ');
          if (field.value is OptionType) {
            outAst.writeln('this.${field.key},');
          } else {
            outAst.writeln('required this.${field.key},');
          }
        }
        outAst.writeln('  });');
      }
      for (final field in tpe.fields.entries) {
        outAst.writeln('  final ${field.value.name} ${field.key};');
      }
      outAst.writeln('}');
    } else if (tpe is EnumType) {
      outAst.writeln('enum ${tpe.name} {');
      for (final value in tpe.values) {
        outAst.writeln('  $value,');
      }
      outAst.writeln('}');
    }
  }

  return '$outAst';
}
