abstract class DartType {
  String get name;
  DartType merge(DartType other);
}

class RawType extends DartType {
  RawType(this.name);
  @override
  final String name;
  @override
  DartType merge(DartType other) {
    if (other is RawType && name == other.name) {
      return this;
    } else {
      throw AssertionError('Type mismatch: $name != ${other.name}');
    }
  }
}

class ClassType extends DartType {
  ClassType? parent;
  @override
  late String name;
  final fields = <String, DartType>{};
  late bool abstract;
  @override
  DartType merge(DartType other) {
    if ((name == 'StringReference' && other.name == 'Name') ||
        (name == 'ExtensionType' && other.name == 'DartType')) {
      return other;
    }
    if (other is ClassType && name == other.name) {
      return this;
    } else {
      throw AssertionError('Type mismatch: $name != ${other.name}');
    }
  }
}

class PairType extends DartType {
  late DartType first;
  late DartType second;
  @override
  String get name => '(${first.name}, ${second.name})';
  @override
  DartType merge(DartType other) {
    if (other is PairType) {
      return PairType()
        ..first = first.merge(other.first)
        ..second = second.merge(other.second);
    } else {
      throw AssertionError('Type mismatch: $name != ${other.name}');
    }
  }
}

class ListType extends DartType {
  late DartType element;
  @override
  String get name => 'List<${element.name}>';
  @override
  DartType merge(DartType other) {
    if (other is ListType) {
      return ListType()..element = element.merge(other.element);
    } else {
      throw AssertionError('Type mismatch: $name != ${other.name}');
    }
  }
}

class OptionType extends DartType {
  late DartType element;
  @override
  String get name => '${element.name}?';
  @override
  DartType merge(DartType other) {
    if (other.name == element.name) {
      return this;
    } else if (other is OptionType) {
      return OptionType()..element = element.merge(other.element);
    } else {
      throw AssertionError('Type mismatch: $name != ${other.name}');
    }
  }
}

class UnionType extends DartType {
  late DartType first;
  late DartType second;
  @override
  String get name {
    final firstName = first is UnionType
        ? first.name
        : (first is ClassType
              ? (first as ClassType).parent!.name
              : throw AssertionError());
    final secondName = second is UnionType
        ? second.name
        : (second is ClassType
              ? (second as ClassType).parent!.name
              : throw AssertionError());
    assert(firstName == secondName);
    return firstName;
  }

  @override
  DartType merge(DartType other) {
    if (name ==
            'PositiveIntLiteral | NegativeIntLiteral | SpecializedIntLiteral | BigIntLiteral' &&
        other.name == 'IntegerLiteral') {
      return other;
    }
    if (other is UnionType) {
      return UnionType()
        ..first = first.merge(other.first)
        ..second = second.merge(other.second);
    } else {
      throw AssertionError('Type mismatch: $name != ${other.name}');
    }
  }
}

class EnumType extends DartType {
  @override
  late String name;
  final values = <String>{};
  @override
  DartType merge(DartType other) {
    if (other is EnumType && name == other.name) {
      return this;
    } else {
      throw AssertionError('Type mismatch: $name != ${other.name}');
    }
  }
}
