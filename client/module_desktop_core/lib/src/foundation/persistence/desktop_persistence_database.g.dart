// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'desktop_persistence_database.dart';

// ignore_for_file: type=lint
class $StringValuesTable extends StringValues
    with TableInfo<$StringValuesTable, StringValue> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $StringValuesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'string_values';
  @override
  VerificationContext validateIntegrity(
    Insertable<StringValue> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  StringValue map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return StringValue(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
    );
  }

  @override
  $StringValuesTable createAlias(String alias) {
    return $StringValuesTable(attachedDatabase, alias);
  }

  @override
  bool get withoutRowId => true;
}

class StringValue extends DataClass implements Insertable<StringValue> {
  final String key;
  final String value;
  const StringValue({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  StringValuesCompanion toCompanion(bool nullToAbsent) {
    return StringValuesCompanion(key: Value(key), value: Value(value));
  }

  factory StringValue.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return StringValue(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  StringValue copyWith({String? key, String? value}) =>
      StringValue(key: key ?? this.key, value: value ?? this.value);
  StringValue copyWithCompanion(StringValuesCompanion data) {
    return StringValue(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('StringValue(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StringValue &&
          other.key == this.key &&
          other.value == this.value);
}

class StringValuesCompanion extends UpdateCompanion<StringValue> {
  final Value<String> key;
  final Value<String> value;
  const StringValuesCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
  });
  StringValuesCompanion.insert({required String key, required String value})
    : key = Value(key),
      value = Value(value);
  static Insertable<StringValue> custom({
    Expression<String>? key,
    Expression<String>? value,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
    });
  }

  StringValuesCompanion copyWith({Value<String>? key, Value<String>? value}) {
    return StringValuesCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('StringValuesCompanion(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }
}

class $BoolValuesTable extends BoolValues
    with TableInfo<$BoolValuesTable, BoolValue> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BoolValuesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<bool> value = GeneratedColumn<bool>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("value" IN (0, 1))',
    ),
  );
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'bool_values';
  @override
  VerificationContext validateIntegrity(
    Insertable<BoolValue> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  BoolValue map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BoolValue(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}value'],
      )!,
    );
  }

  @override
  $BoolValuesTable createAlias(String alias) {
    return $BoolValuesTable(attachedDatabase, alias);
  }

  @override
  bool get withoutRowId => true;
}

class BoolValue extends DataClass implements Insertable<BoolValue> {
  final String key;
  final bool value;
  const BoolValue({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<bool>(value);
    return map;
  }

  BoolValuesCompanion toCompanion(bool nullToAbsent) {
    return BoolValuesCompanion(key: Value(key), value: Value(value));
  }

  factory BoolValue.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BoolValue(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<bool>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<bool>(value),
    };
  }

  BoolValue copyWith({String? key, bool? value}) =>
      BoolValue(key: key ?? this.key, value: value ?? this.value);
  BoolValue copyWithCompanion(BoolValuesCompanion data) {
    return BoolValue(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BoolValue(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BoolValue &&
          other.key == this.key &&
          other.value == this.value);
}

class BoolValuesCompanion extends UpdateCompanion<BoolValue> {
  final Value<String> key;
  final Value<bool> value;
  const BoolValuesCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
  });
  BoolValuesCompanion.insert({required String key, required bool value})
    : key = Value(key),
      value = Value(value);
  static Insertable<BoolValue> custom({
    Expression<String>? key,
    Expression<bool>? value,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
    });
  }

  BoolValuesCompanion copyWith({Value<String>? key, Value<bool>? value}) {
    return BoolValuesCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<bool>(value.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BoolValuesCompanion(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }
}

class $EncryptedValuesTable extends EncryptedValues
    with TableInfo<$EncryptedValuesTable, EncryptedValue> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $EncryptedValuesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ciphertextMeta = const VerificationMeta(
    'ciphertext',
  );
  @override
  late final GeneratedColumn<Uint8List> ciphertext = GeneratedColumn<Uint8List>(
    'ciphertext',
    aliasedName,
    false,
    type: DriftSqlType.blob,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, ciphertext];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'encrypted_values';
  @override
  VerificationContext validateIntegrity(
    Insertable<EncryptedValue> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('ciphertext')) {
      context.handle(
        _ciphertextMeta,
        ciphertext.isAcceptableOrUnknown(data['ciphertext']!, _ciphertextMeta),
      );
    } else if (isInserting) {
      context.missing(_ciphertextMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  EncryptedValue map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return EncryptedValue(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      ciphertext: attachedDatabase.typeMapping.read(
        DriftSqlType.blob,
        data['${effectivePrefix}ciphertext'],
      )!,
    );
  }

  @override
  $EncryptedValuesTable createAlias(String alias) {
    return $EncryptedValuesTable(attachedDatabase, alias);
  }

  @override
  bool get withoutRowId => true;
}

class EncryptedValue extends DataClass implements Insertable<EncryptedValue> {
  final String key;
  final Uint8List ciphertext;
  const EncryptedValue({required this.key, required this.ciphertext});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['ciphertext'] = Variable<Uint8List>(ciphertext);
    return map;
  }

  EncryptedValuesCompanion toCompanion(bool nullToAbsent) {
    return EncryptedValuesCompanion(
      key: Value(key),
      ciphertext: Value(ciphertext),
    );
  }

  factory EncryptedValue.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return EncryptedValue(
      key: serializer.fromJson<String>(json['key']),
      ciphertext: serializer.fromJson<Uint8List>(json['ciphertext']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'ciphertext': serializer.toJson<Uint8List>(ciphertext),
    };
  }

  EncryptedValue copyWith({String? key, Uint8List? ciphertext}) =>
      EncryptedValue(
        key: key ?? this.key,
        ciphertext: ciphertext ?? this.ciphertext,
      );
  EncryptedValue copyWithCompanion(EncryptedValuesCompanion data) {
    return EncryptedValue(
      key: data.key.present ? data.key.value : this.key,
      ciphertext: data.ciphertext.present
          ? data.ciphertext.value
          : this.ciphertext,
    );
  }

  @override
  String toString() {
    return (StringBuffer('EncryptedValue(')
          ..write('key: $key, ')
          ..write('ciphertext: $ciphertext')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, $driftBlobEquality.hash(ciphertext));
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EncryptedValue &&
          other.key == this.key &&
          $driftBlobEquality.equals(other.ciphertext, this.ciphertext));
}

class EncryptedValuesCompanion extends UpdateCompanion<EncryptedValue> {
  final Value<String> key;
  final Value<Uint8List> ciphertext;
  const EncryptedValuesCompanion({
    this.key = const Value.absent(),
    this.ciphertext = const Value.absent(),
  });
  EncryptedValuesCompanion.insert({
    required String key,
    required Uint8List ciphertext,
  }) : key = Value(key),
       ciphertext = Value(ciphertext);
  static Insertable<EncryptedValue> custom({
    Expression<String>? key,
    Expression<Uint8List>? ciphertext,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (ciphertext != null) 'ciphertext': ciphertext,
    });
  }

  EncryptedValuesCompanion copyWith({
    Value<String>? key,
    Value<Uint8List>? ciphertext,
  }) {
    return EncryptedValuesCompanion(
      key: key ?? this.key,
      ciphertext: ciphertext ?? this.ciphertext,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (ciphertext.present) {
      map['ciphertext'] = Variable<Uint8List>(ciphertext.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('EncryptedValuesCompanion(')
          ..write('key: $key, ')
          ..write('ciphertext: $ciphertext')
          ..write(')'))
        .toString();
  }
}

abstract class _$DesktopPersistenceDatabase extends GeneratedDatabase {
  _$DesktopPersistenceDatabase(QueryExecutor e) : super(e);
  late final $StringValuesTable stringValues = $StringValuesTable(this);
  late final $BoolValuesTable boolValues = $BoolValuesTable(this);
  late final $EncryptedValuesTable encryptedValues = $EncryptedValuesTable(
    this,
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    stringValues,
    boolValues,
    encryptedValues,
  ];
}
