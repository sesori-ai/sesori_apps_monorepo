// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chat_history_database.dart';

// ignore_for_file: type=lint
mixin $HistoryMessagesTableTableToColumns
    implements Insertable<HistoryMessagesTableData> {
  String get sessionId;
  String get messageId;
  int get seq;
  String get infoJson;
  int get updatedAt;
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['session_id'] = Variable<String>(sessionId);
    map['message_id'] = Variable<String>(messageId);
    map['seq'] = Variable<int>(seq);
    map['info_json'] = Variable<String>(infoJson);
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }
}

class $HistoryMessagesTableTable extends HistoryMessagesTable
    with TableInfo<$HistoryMessagesTableTable, HistoryMessagesTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $HistoryMessagesTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _sessionIdMeta = const VerificationMeta(
    'sessionId',
  );
  @override
  late final GeneratedColumn<String> sessionId = GeneratedColumn<String>(
    'session_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _messageIdMeta = const VerificationMeta(
    'messageId',
  );
  @override
  late final GeneratedColumn<String> messageId = GeneratedColumn<String>(
    'message_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _seqMeta = const VerificationMeta('seq');
  @override
  late final GeneratedColumn<int> seq = GeneratedColumn<int>(
    'seq',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _infoJsonMeta = const VerificationMeta(
    'infoJson',
  );
  @override
  late final GeneratedColumn<String> infoJson = GeneratedColumn<String>(
    'info_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    sessionId,
    messageId,
    seq,
    infoJson,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'history_messages';
  @override
  VerificationContext validateIntegrity(
    Insertable<HistoryMessagesTableData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('session_id')) {
      context.handle(
        _sessionIdMeta,
        sessionId.isAcceptableOrUnknown(data['session_id']!, _sessionIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sessionIdMeta);
    }
    if (data.containsKey('message_id')) {
      context.handle(
        _messageIdMeta,
        messageId.isAcceptableOrUnknown(data['message_id']!, _messageIdMeta),
      );
    } else if (isInserting) {
      context.missing(_messageIdMeta);
    }
    if (data.containsKey('seq')) {
      context.handle(
        _seqMeta,
        seq.isAcceptableOrUnknown(data['seq']!, _seqMeta),
      );
    } else if (isInserting) {
      context.missing(_seqMeta);
    }
    if (data.containsKey('info_json')) {
      context.handle(
        _infoJsonMeta,
        infoJson.isAcceptableOrUnknown(data['info_json']!, _infoJsonMeta),
      );
    } else if (isInserting) {
      context.missing(_infoJsonMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {sessionId, messageId};
  @override
  HistoryMessagesTableData map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return HistoryMessagesTableData(
      sessionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}session_id'],
      )!,
      messageId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}message_id'],
      )!,
      seq: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}seq'],
      )!,
      infoJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}info_json'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $HistoryMessagesTableTable createAlias(String alias) {
    return $HistoryMessagesTableTable(attachedDatabase, alias);
  }

  @override
  bool get withoutRowId => true;
}

class HistoryMessagesTableData extends DataClass
    with $HistoryMessagesTableTableToColumns {
  @override
  final String sessionId;
  @override
  final String messageId;
  @override
  final int seq;
  @override
  final String infoJson;
  @override
  final int updatedAt;
  const HistoryMessagesTableData({
    required this.sessionId,
    required this.messageId,
    required this.seq,
    required this.infoJson,
    required this.updatedAt,
  });
  HistoryMessagesTableCompanion toCompanion(bool nullToAbsent) {
    return HistoryMessagesTableCompanion(
      sessionId: Value(sessionId),
      messageId: Value(messageId),
      seq: Value(seq),
      infoJson: Value(infoJson),
      updatedAt: Value(updatedAt),
    );
  }

  factory HistoryMessagesTableData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return HistoryMessagesTableData(
      sessionId: serializer.fromJson<String>(json['sessionId']),
      messageId: serializer.fromJson<String>(json['messageId']),
      seq: serializer.fromJson<int>(json['seq']),
      infoJson: serializer.fromJson<String>(json['infoJson']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'sessionId': serializer.toJson<String>(sessionId),
      'messageId': serializer.toJson<String>(messageId),
      'seq': serializer.toJson<int>(seq),
      'infoJson': serializer.toJson<String>(infoJson),
      'updatedAt': serializer.toJson<int>(updatedAt),
    };
  }

  HistoryMessagesTableData copyWith({
    String? sessionId,
    String? messageId,
    int? seq,
    String? infoJson,
    int? updatedAt,
  }) => HistoryMessagesTableData(
    sessionId: sessionId ?? this.sessionId,
    messageId: messageId ?? this.messageId,
    seq: seq ?? this.seq,
    infoJson: infoJson ?? this.infoJson,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  HistoryMessagesTableData copyWithCompanion(
    HistoryMessagesTableCompanion data,
  ) {
    return HistoryMessagesTableData(
      sessionId: data.sessionId.present ? data.sessionId.value : this.sessionId,
      messageId: data.messageId.present ? data.messageId.value : this.messageId,
      seq: data.seq.present ? data.seq.value : this.seq,
      infoJson: data.infoJson.present ? data.infoJson.value : this.infoJson,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('HistoryMessagesTableData(')
          ..write('sessionId: $sessionId, ')
          ..write('messageId: $messageId, ')
          ..write('seq: $seq, ')
          ..write('infoJson: $infoJson, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(sessionId, messageId, seq, infoJson, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is HistoryMessagesTableData &&
          other.sessionId == this.sessionId &&
          other.messageId == this.messageId &&
          other.seq == this.seq &&
          other.infoJson == this.infoJson &&
          other.updatedAt == this.updatedAt);
}

class HistoryMessagesTableCompanion
    extends UpdateCompanion<HistoryMessagesTableData> {
  final Value<String> sessionId;
  final Value<String> messageId;
  final Value<int> seq;
  final Value<String> infoJson;
  final Value<int> updatedAt;
  const HistoryMessagesTableCompanion({
    this.sessionId = const Value.absent(),
    this.messageId = const Value.absent(),
    this.seq = const Value.absent(),
    this.infoJson = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  HistoryMessagesTableCompanion.insert({
    required String sessionId,
    required String messageId,
    required int seq,
    required String infoJson,
    required int updatedAt,
  }) : sessionId = Value(sessionId),
       messageId = Value(messageId),
       seq = Value(seq),
       infoJson = Value(infoJson),
       updatedAt = Value(updatedAt);
  static Insertable<HistoryMessagesTableData> custom({
    Expression<String>? sessionId,
    Expression<String>? messageId,
    Expression<int>? seq,
    Expression<String>? infoJson,
    Expression<int>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (sessionId != null) 'session_id': sessionId,
      if (messageId != null) 'message_id': messageId,
      if (seq != null) 'seq': seq,
      if (infoJson != null) 'info_json': infoJson,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  HistoryMessagesTableCompanion copyWith({
    Value<String>? sessionId,
    Value<String>? messageId,
    Value<int>? seq,
    Value<String>? infoJson,
    Value<int>? updatedAt,
  }) {
    return HistoryMessagesTableCompanion(
      sessionId: sessionId ?? this.sessionId,
      messageId: messageId ?? this.messageId,
      seq: seq ?? this.seq,
      infoJson: infoJson ?? this.infoJson,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (sessionId.present) {
      map['session_id'] = Variable<String>(sessionId.value);
    }
    if (messageId.present) {
      map['message_id'] = Variable<String>(messageId.value);
    }
    if (seq.present) {
      map['seq'] = Variable<int>(seq.value);
    }
    if (infoJson.present) {
      map['info_json'] = Variable<String>(infoJson.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('HistoryMessagesTableCompanion(')
          ..write('sessionId: $sessionId, ')
          ..write('messageId: $messageId, ')
          ..write('seq: $seq, ')
          ..write('infoJson: $infoJson, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

mixin $HistoryPartsTableTableToColumns
    implements Insertable<HistoryPartsTableData> {
  String get sessionId;
  String get messageId;
  String get partId;
  int get orderIndex;
  String get partJson;
  int get updatedAt;
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['session_id'] = Variable<String>(sessionId);
    map['message_id'] = Variable<String>(messageId);
    map['part_id'] = Variable<String>(partId);
    map['order_index'] = Variable<int>(orderIndex);
    map['part_json'] = Variable<String>(partJson);
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }
}

class $HistoryPartsTableTable extends HistoryPartsTable
    with TableInfo<$HistoryPartsTableTable, HistoryPartsTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $HistoryPartsTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _sessionIdMeta = const VerificationMeta(
    'sessionId',
  );
  @override
  late final GeneratedColumn<String> sessionId = GeneratedColumn<String>(
    'session_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _messageIdMeta = const VerificationMeta(
    'messageId',
  );
  @override
  late final GeneratedColumn<String> messageId = GeneratedColumn<String>(
    'message_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _partIdMeta = const VerificationMeta('partId');
  @override
  late final GeneratedColumn<String> partId = GeneratedColumn<String>(
    'part_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _orderIndexMeta = const VerificationMeta(
    'orderIndex',
  );
  @override
  late final GeneratedColumn<int> orderIndex = GeneratedColumn<int>(
    'order_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _partJsonMeta = const VerificationMeta(
    'partJson',
  );
  @override
  late final GeneratedColumn<String> partJson = GeneratedColumn<String>(
    'part_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    sessionId,
    messageId,
    partId,
    orderIndex,
    partJson,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'history_parts';
  @override
  VerificationContext validateIntegrity(
    Insertable<HistoryPartsTableData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('session_id')) {
      context.handle(
        _sessionIdMeta,
        sessionId.isAcceptableOrUnknown(data['session_id']!, _sessionIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sessionIdMeta);
    }
    if (data.containsKey('message_id')) {
      context.handle(
        _messageIdMeta,
        messageId.isAcceptableOrUnknown(data['message_id']!, _messageIdMeta),
      );
    } else if (isInserting) {
      context.missing(_messageIdMeta);
    }
    if (data.containsKey('part_id')) {
      context.handle(
        _partIdMeta,
        partId.isAcceptableOrUnknown(data['part_id']!, _partIdMeta),
      );
    } else if (isInserting) {
      context.missing(_partIdMeta);
    }
    if (data.containsKey('order_index')) {
      context.handle(
        _orderIndexMeta,
        orderIndex.isAcceptableOrUnknown(data['order_index']!, _orderIndexMeta),
      );
    } else if (isInserting) {
      context.missing(_orderIndexMeta);
    }
    if (data.containsKey('part_json')) {
      context.handle(
        _partJsonMeta,
        partJson.isAcceptableOrUnknown(data['part_json']!, _partJsonMeta),
      );
    } else if (isInserting) {
      context.missing(_partJsonMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {sessionId, messageId, partId};
  @override
  HistoryPartsTableData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return HistoryPartsTableData(
      sessionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}session_id'],
      )!,
      messageId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}message_id'],
      )!,
      partId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}part_id'],
      )!,
      orderIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}order_index'],
      )!,
      partJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}part_json'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $HistoryPartsTableTable createAlias(String alias) {
    return $HistoryPartsTableTable(attachedDatabase, alias);
  }

  @override
  bool get withoutRowId => true;
}

class HistoryPartsTableData extends DataClass
    with $HistoryPartsTableTableToColumns {
  @override
  final String sessionId;
  @override
  final String messageId;
  @override
  final String partId;
  @override
  final int orderIndex;
  @override
  final String partJson;
  @override
  final int updatedAt;
  const HistoryPartsTableData({
    required this.sessionId,
    required this.messageId,
    required this.partId,
    required this.orderIndex,
    required this.partJson,
    required this.updatedAt,
  });
  HistoryPartsTableCompanion toCompanion(bool nullToAbsent) {
    return HistoryPartsTableCompanion(
      sessionId: Value(sessionId),
      messageId: Value(messageId),
      partId: Value(partId),
      orderIndex: Value(orderIndex),
      partJson: Value(partJson),
      updatedAt: Value(updatedAt),
    );
  }

  factory HistoryPartsTableData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return HistoryPartsTableData(
      sessionId: serializer.fromJson<String>(json['sessionId']),
      messageId: serializer.fromJson<String>(json['messageId']),
      partId: serializer.fromJson<String>(json['partId']),
      orderIndex: serializer.fromJson<int>(json['orderIndex']),
      partJson: serializer.fromJson<String>(json['partJson']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'sessionId': serializer.toJson<String>(sessionId),
      'messageId': serializer.toJson<String>(messageId),
      'partId': serializer.toJson<String>(partId),
      'orderIndex': serializer.toJson<int>(orderIndex),
      'partJson': serializer.toJson<String>(partJson),
      'updatedAt': serializer.toJson<int>(updatedAt),
    };
  }

  HistoryPartsTableData copyWith({
    String? sessionId,
    String? messageId,
    String? partId,
    int? orderIndex,
    String? partJson,
    int? updatedAt,
  }) => HistoryPartsTableData(
    sessionId: sessionId ?? this.sessionId,
    messageId: messageId ?? this.messageId,
    partId: partId ?? this.partId,
    orderIndex: orderIndex ?? this.orderIndex,
    partJson: partJson ?? this.partJson,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  HistoryPartsTableData copyWithCompanion(HistoryPartsTableCompanion data) {
    return HistoryPartsTableData(
      sessionId: data.sessionId.present ? data.sessionId.value : this.sessionId,
      messageId: data.messageId.present ? data.messageId.value : this.messageId,
      partId: data.partId.present ? data.partId.value : this.partId,
      orderIndex: data.orderIndex.present
          ? data.orderIndex.value
          : this.orderIndex,
      partJson: data.partJson.present ? data.partJson.value : this.partJson,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('HistoryPartsTableData(')
          ..write('sessionId: $sessionId, ')
          ..write('messageId: $messageId, ')
          ..write('partId: $partId, ')
          ..write('orderIndex: $orderIndex, ')
          ..write('partJson: $partJson, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    sessionId,
    messageId,
    partId,
    orderIndex,
    partJson,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is HistoryPartsTableData &&
          other.sessionId == this.sessionId &&
          other.messageId == this.messageId &&
          other.partId == this.partId &&
          other.orderIndex == this.orderIndex &&
          other.partJson == this.partJson &&
          other.updatedAt == this.updatedAt);
}

class HistoryPartsTableCompanion
    extends UpdateCompanion<HistoryPartsTableData> {
  final Value<String> sessionId;
  final Value<String> messageId;
  final Value<String> partId;
  final Value<int> orderIndex;
  final Value<String> partJson;
  final Value<int> updatedAt;
  const HistoryPartsTableCompanion({
    this.sessionId = const Value.absent(),
    this.messageId = const Value.absent(),
    this.partId = const Value.absent(),
    this.orderIndex = const Value.absent(),
    this.partJson = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  HistoryPartsTableCompanion.insert({
    required String sessionId,
    required String messageId,
    required String partId,
    required int orderIndex,
    required String partJson,
    required int updatedAt,
  }) : sessionId = Value(sessionId),
       messageId = Value(messageId),
       partId = Value(partId),
       orderIndex = Value(orderIndex),
       partJson = Value(partJson),
       updatedAt = Value(updatedAt);
  static Insertable<HistoryPartsTableData> custom({
    Expression<String>? sessionId,
    Expression<String>? messageId,
    Expression<String>? partId,
    Expression<int>? orderIndex,
    Expression<String>? partJson,
    Expression<int>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (sessionId != null) 'session_id': sessionId,
      if (messageId != null) 'message_id': messageId,
      if (partId != null) 'part_id': partId,
      if (orderIndex != null) 'order_index': orderIndex,
      if (partJson != null) 'part_json': partJson,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  HistoryPartsTableCompanion copyWith({
    Value<String>? sessionId,
    Value<String>? messageId,
    Value<String>? partId,
    Value<int>? orderIndex,
    Value<String>? partJson,
    Value<int>? updatedAt,
  }) {
    return HistoryPartsTableCompanion(
      sessionId: sessionId ?? this.sessionId,
      messageId: messageId ?? this.messageId,
      partId: partId ?? this.partId,
      orderIndex: orderIndex ?? this.orderIndex,
      partJson: partJson ?? this.partJson,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (sessionId.present) {
      map['session_id'] = Variable<String>(sessionId.value);
    }
    if (messageId.present) {
      map['message_id'] = Variable<String>(messageId.value);
    }
    if (partId.present) {
      map['part_id'] = Variable<String>(partId.value);
    }
    if (orderIndex.present) {
      map['order_index'] = Variable<int>(orderIndex.value);
    }
    if (partJson.present) {
      map['part_json'] = Variable<String>(partJson.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('HistoryPartsTableCompanion(')
          ..write('sessionId: $sessionId, ')
          ..write('messageId: $messageId, ')
          ..write('partId: $partId, ')
          ..write('orderIndex: $orderIndex, ')
          ..write('partJson: $partJson, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

mixin $HistorySyncStateTableTableToColumns
    implements Insertable<HistorySyncStateTableData> {
  String get sessionId;
  int get watermark;
  int get backendActivityAt;
  int? get syncedAt;
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['session_id'] = Variable<String>(sessionId);
    map['watermark'] = Variable<int>(watermark);
    map['backend_activity_at'] = Variable<int>(backendActivityAt);
    if (!nullToAbsent || syncedAt != null) {
      map['synced_at'] = Variable<int>(syncedAt);
    }
    return map;
  }
}

class $HistorySyncStateTableTable extends HistorySyncStateTable
    with TableInfo<$HistorySyncStateTableTable, HistorySyncStateTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $HistorySyncStateTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _sessionIdMeta = const VerificationMeta(
    'sessionId',
  );
  @override
  late final GeneratedColumn<String> sessionId = GeneratedColumn<String>(
    'session_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _watermarkMeta = const VerificationMeta(
    'watermark',
  );
  @override
  late final GeneratedColumn<int> watermark = GeneratedColumn<int>(
    'watermark',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _backendActivityAtMeta = const VerificationMeta(
    'backendActivityAt',
  );
  @override
  late final GeneratedColumn<int> backendActivityAt = GeneratedColumn<int>(
    'backend_activity_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _syncedAtMeta = const VerificationMeta(
    'syncedAt',
  );
  @override
  late final GeneratedColumn<int> syncedAt = GeneratedColumn<int>(
    'synced_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    sessionId,
    watermark,
    backendActivityAt,
    syncedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'history_sync_state';
  @override
  VerificationContext validateIntegrity(
    Insertable<HistorySyncStateTableData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('session_id')) {
      context.handle(
        _sessionIdMeta,
        sessionId.isAcceptableOrUnknown(data['session_id']!, _sessionIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sessionIdMeta);
    }
    if (data.containsKey('watermark')) {
      context.handle(
        _watermarkMeta,
        watermark.isAcceptableOrUnknown(data['watermark']!, _watermarkMeta),
      );
    } else if (isInserting) {
      context.missing(_watermarkMeta);
    }
    if (data.containsKey('backend_activity_at')) {
      context.handle(
        _backendActivityAtMeta,
        backendActivityAt.isAcceptableOrUnknown(
          data['backend_activity_at']!,
          _backendActivityAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_backendActivityAtMeta);
    }
    if (data.containsKey('synced_at')) {
      context.handle(
        _syncedAtMeta,
        syncedAt.isAcceptableOrUnknown(data['synced_at']!, _syncedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {sessionId};
  @override
  HistorySyncStateTableData map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return HistorySyncStateTableData(
      sessionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}session_id'],
      )!,
      watermark: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}watermark'],
      )!,
      backendActivityAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}backend_activity_at'],
      )!,
      syncedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}synced_at'],
      ),
    );
  }

  @override
  $HistorySyncStateTableTable createAlias(String alias) {
    return $HistorySyncStateTableTable(attachedDatabase, alias);
  }

  @override
  bool get withoutRowId => true;
}

class HistorySyncStateTableData extends DataClass
    with $HistorySyncStateTableTableToColumns {
  @override
  final String sessionId;
  @override
  final int watermark;
  @override
  final int backendActivityAt;
  @override
  final int? syncedAt;
  const HistorySyncStateTableData({
    required this.sessionId,
    required this.watermark,
    required this.backendActivityAt,
    this.syncedAt,
  });
  HistorySyncStateTableCompanion toCompanion(bool nullToAbsent) {
    return HistorySyncStateTableCompanion(
      sessionId: Value(sessionId),
      watermark: Value(watermark),
      backendActivityAt: Value(backendActivityAt),
      syncedAt: syncedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(syncedAt),
    );
  }

  factory HistorySyncStateTableData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return HistorySyncStateTableData(
      sessionId: serializer.fromJson<String>(json['sessionId']),
      watermark: serializer.fromJson<int>(json['watermark']),
      backendActivityAt: serializer.fromJson<int>(json['backendActivityAt']),
      syncedAt: serializer.fromJson<int?>(json['syncedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'sessionId': serializer.toJson<String>(sessionId),
      'watermark': serializer.toJson<int>(watermark),
      'backendActivityAt': serializer.toJson<int>(backendActivityAt),
      'syncedAt': serializer.toJson<int?>(syncedAt),
    };
  }

  HistorySyncStateTableData copyWith({
    String? sessionId,
    int? watermark,
    int? backendActivityAt,
    Value<int?> syncedAt = const Value.absent(),
  }) => HistorySyncStateTableData(
    sessionId: sessionId ?? this.sessionId,
    watermark: watermark ?? this.watermark,
    backendActivityAt: backendActivityAt ?? this.backendActivityAt,
    syncedAt: syncedAt.present ? syncedAt.value : this.syncedAt,
  );
  HistorySyncStateTableData copyWithCompanion(
    HistorySyncStateTableCompanion data,
  ) {
    return HistorySyncStateTableData(
      sessionId: data.sessionId.present ? data.sessionId.value : this.sessionId,
      watermark: data.watermark.present ? data.watermark.value : this.watermark,
      backendActivityAt: data.backendActivityAt.present
          ? data.backendActivityAt.value
          : this.backendActivityAt,
      syncedAt: data.syncedAt.present ? data.syncedAt.value : this.syncedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('HistorySyncStateTableData(')
          ..write('sessionId: $sessionId, ')
          ..write('watermark: $watermark, ')
          ..write('backendActivityAt: $backendActivityAt, ')
          ..write('syncedAt: $syncedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(sessionId, watermark, backendActivityAt, syncedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is HistorySyncStateTableData &&
          other.sessionId == this.sessionId &&
          other.watermark == this.watermark &&
          other.backendActivityAt == this.backendActivityAt &&
          other.syncedAt == this.syncedAt);
}

class HistorySyncStateTableCompanion
    extends UpdateCompanion<HistorySyncStateTableData> {
  final Value<String> sessionId;
  final Value<int> watermark;
  final Value<int> backendActivityAt;
  final Value<int?> syncedAt;
  const HistorySyncStateTableCompanion({
    this.sessionId = const Value.absent(),
    this.watermark = const Value.absent(),
    this.backendActivityAt = const Value.absent(),
    this.syncedAt = const Value.absent(),
  });
  HistorySyncStateTableCompanion.insert({
    required String sessionId,
    required int watermark,
    required int backendActivityAt,
    this.syncedAt = const Value.absent(),
  }) : sessionId = Value(sessionId),
       watermark = Value(watermark),
       backendActivityAt = Value(backendActivityAt);
  static Insertable<HistorySyncStateTableData> custom({
    Expression<String>? sessionId,
    Expression<int>? watermark,
    Expression<int>? backendActivityAt,
    Expression<int>? syncedAt,
  }) {
    return RawValuesInsertable({
      if (sessionId != null) 'session_id': sessionId,
      if (watermark != null) 'watermark': watermark,
      if (backendActivityAt != null) 'backend_activity_at': backendActivityAt,
      if (syncedAt != null) 'synced_at': syncedAt,
    });
  }

  HistorySyncStateTableCompanion copyWith({
    Value<String>? sessionId,
    Value<int>? watermark,
    Value<int>? backendActivityAt,
    Value<int?>? syncedAt,
  }) {
    return HistorySyncStateTableCompanion(
      sessionId: sessionId ?? this.sessionId,
      watermark: watermark ?? this.watermark,
      backendActivityAt: backendActivityAt ?? this.backendActivityAt,
      syncedAt: syncedAt ?? this.syncedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (sessionId.present) {
      map['session_id'] = Variable<String>(sessionId.value);
    }
    if (watermark.present) {
      map['watermark'] = Variable<int>(watermark.value);
    }
    if (backendActivityAt.present) {
      map['backend_activity_at'] = Variable<int>(backendActivityAt.value);
    }
    if (syncedAt.present) {
      map['synced_at'] = Variable<int>(syncedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('HistorySyncStateTableCompanion(')
          ..write('sessionId: $sessionId, ')
          ..write('watermark: $watermark, ')
          ..write('backendActivityAt: $backendActivityAt, ')
          ..write('syncedAt: $syncedAt')
          ..write(')'))
        .toString();
  }
}

abstract class _$ChatHistoryDatabase extends GeneratedDatabase {
  _$ChatHistoryDatabase(QueryExecutor e) : super(e);
  $ChatHistoryDatabaseManager get managers => $ChatHistoryDatabaseManager(this);
  late final $HistoryMessagesTableTable historyMessagesTable =
      $HistoryMessagesTableTable(this);
  late final $HistoryPartsTableTable historyPartsTable =
      $HistoryPartsTableTable(this);
  late final $HistorySyncStateTableTable historySyncStateTable =
      $HistorySyncStateTableTable(this);
  late final Index idxHistoryMessagesSeq = Index(
    'idx_history_messages_seq',
    'CREATE UNIQUE INDEX idx_history_messages_seq ON history_messages (session_id, seq)',
  );
  late final Index idxHistoryPartsOrder = Index(
    'idx_history_parts_order',
    'CREATE INDEX idx_history_parts_order ON history_parts (session_id, message_id, order_index)',
  );
  late final ChatHistoryDao chatHistoryDao = ChatHistoryDao(
    this as ChatHistoryDatabase,
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    historyMessagesTable,
    historyPartsTable,
    historySyncStateTable,
    idxHistoryMessagesSeq,
    idxHistoryPartsOrder,
  ];
}

typedef $$HistoryMessagesTableTableCreateCompanionBuilder =
    HistoryMessagesTableCompanion Function({
      required String sessionId,
      required String messageId,
      required int seq,
      required String infoJson,
      required int updatedAt,
    });
typedef $$HistoryMessagesTableTableUpdateCompanionBuilder =
    HistoryMessagesTableCompanion Function({
      Value<String> sessionId,
      Value<String> messageId,
      Value<int> seq,
      Value<String> infoJson,
      Value<int> updatedAt,
    });

class $$HistoryMessagesTableTableFilterComposer
    extends Composer<_$ChatHistoryDatabase, $HistoryMessagesTableTable> {
  $$HistoryMessagesTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get sessionId => $composableBuilder(
    column: $table.sessionId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get messageId => $composableBuilder(
    column: $table.messageId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get seq => $composableBuilder(
    column: $table.seq,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get infoJson => $composableBuilder(
    column: $table.infoJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$HistoryMessagesTableTableOrderingComposer
    extends Composer<_$ChatHistoryDatabase, $HistoryMessagesTableTable> {
  $$HistoryMessagesTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get sessionId => $composableBuilder(
    column: $table.sessionId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get messageId => $composableBuilder(
    column: $table.messageId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get seq => $composableBuilder(
    column: $table.seq,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get infoJson => $composableBuilder(
    column: $table.infoJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$HistoryMessagesTableTableAnnotationComposer
    extends Composer<_$ChatHistoryDatabase, $HistoryMessagesTableTable> {
  $$HistoryMessagesTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get sessionId =>
      $composableBuilder(column: $table.sessionId, builder: (column) => column);

  GeneratedColumn<String> get messageId =>
      $composableBuilder(column: $table.messageId, builder: (column) => column);

  GeneratedColumn<int> get seq =>
      $composableBuilder(column: $table.seq, builder: (column) => column);

  GeneratedColumn<String> get infoJson =>
      $composableBuilder(column: $table.infoJson, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$HistoryMessagesTableTableTableManager
    extends
        RootTableManager<
          _$ChatHistoryDatabase,
          $HistoryMessagesTableTable,
          HistoryMessagesTableData,
          $$HistoryMessagesTableTableFilterComposer,
          $$HistoryMessagesTableTableOrderingComposer,
          $$HistoryMessagesTableTableAnnotationComposer,
          $$HistoryMessagesTableTableCreateCompanionBuilder,
          $$HistoryMessagesTableTableUpdateCompanionBuilder,
          (
            HistoryMessagesTableData,
            BaseReferences<
              _$ChatHistoryDatabase,
              $HistoryMessagesTableTable,
              HistoryMessagesTableData
            >,
          ),
          HistoryMessagesTableData,
          PrefetchHooks Function()
        > {
  $$HistoryMessagesTableTableTableManager(
    _$ChatHistoryDatabase db,
    $HistoryMessagesTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$HistoryMessagesTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$HistoryMessagesTableTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$HistoryMessagesTableTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> sessionId = const Value.absent(),
                Value<String> messageId = const Value.absent(),
                Value<int> seq = const Value.absent(),
                Value<String> infoJson = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
              }) => HistoryMessagesTableCompanion(
                sessionId: sessionId,
                messageId: messageId,
                seq: seq,
                infoJson: infoJson,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                required String sessionId,
                required String messageId,
                required int seq,
                required String infoJson,
                required int updatedAt,
              }) => HistoryMessagesTableCompanion.insert(
                sessionId: sessionId,
                messageId: messageId,
                seq: seq,
                infoJson: infoJson,
                updatedAt: updatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$HistoryMessagesTableTableProcessedTableManager =
    ProcessedTableManager<
      _$ChatHistoryDatabase,
      $HistoryMessagesTableTable,
      HistoryMessagesTableData,
      $$HistoryMessagesTableTableFilterComposer,
      $$HistoryMessagesTableTableOrderingComposer,
      $$HistoryMessagesTableTableAnnotationComposer,
      $$HistoryMessagesTableTableCreateCompanionBuilder,
      $$HistoryMessagesTableTableUpdateCompanionBuilder,
      (
        HistoryMessagesTableData,
        BaseReferences<
          _$ChatHistoryDatabase,
          $HistoryMessagesTableTable,
          HistoryMessagesTableData
        >,
      ),
      HistoryMessagesTableData,
      PrefetchHooks Function()
    >;
typedef $$HistoryPartsTableTableCreateCompanionBuilder =
    HistoryPartsTableCompanion Function({
      required String sessionId,
      required String messageId,
      required String partId,
      required int orderIndex,
      required String partJson,
      required int updatedAt,
    });
typedef $$HistoryPartsTableTableUpdateCompanionBuilder =
    HistoryPartsTableCompanion Function({
      Value<String> sessionId,
      Value<String> messageId,
      Value<String> partId,
      Value<int> orderIndex,
      Value<String> partJson,
      Value<int> updatedAt,
    });

class $$HistoryPartsTableTableFilterComposer
    extends Composer<_$ChatHistoryDatabase, $HistoryPartsTableTable> {
  $$HistoryPartsTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get sessionId => $composableBuilder(
    column: $table.sessionId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get messageId => $composableBuilder(
    column: $table.messageId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get partId => $composableBuilder(
    column: $table.partId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get orderIndex => $composableBuilder(
    column: $table.orderIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get partJson => $composableBuilder(
    column: $table.partJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$HistoryPartsTableTableOrderingComposer
    extends Composer<_$ChatHistoryDatabase, $HistoryPartsTableTable> {
  $$HistoryPartsTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get sessionId => $composableBuilder(
    column: $table.sessionId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get messageId => $composableBuilder(
    column: $table.messageId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get partId => $composableBuilder(
    column: $table.partId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get orderIndex => $composableBuilder(
    column: $table.orderIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get partJson => $composableBuilder(
    column: $table.partJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$HistoryPartsTableTableAnnotationComposer
    extends Composer<_$ChatHistoryDatabase, $HistoryPartsTableTable> {
  $$HistoryPartsTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get sessionId =>
      $composableBuilder(column: $table.sessionId, builder: (column) => column);

  GeneratedColumn<String> get messageId =>
      $composableBuilder(column: $table.messageId, builder: (column) => column);

  GeneratedColumn<String> get partId =>
      $composableBuilder(column: $table.partId, builder: (column) => column);

  GeneratedColumn<int> get orderIndex => $composableBuilder(
    column: $table.orderIndex,
    builder: (column) => column,
  );

  GeneratedColumn<String> get partJson =>
      $composableBuilder(column: $table.partJson, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$HistoryPartsTableTableTableManager
    extends
        RootTableManager<
          _$ChatHistoryDatabase,
          $HistoryPartsTableTable,
          HistoryPartsTableData,
          $$HistoryPartsTableTableFilterComposer,
          $$HistoryPartsTableTableOrderingComposer,
          $$HistoryPartsTableTableAnnotationComposer,
          $$HistoryPartsTableTableCreateCompanionBuilder,
          $$HistoryPartsTableTableUpdateCompanionBuilder,
          (
            HistoryPartsTableData,
            BaseReferences<
              _$ChatHistoryDatabase,
              $HistoryPartsTableTable,
              HistoryPartsTableData
            >,
          ),
          HistoryPartsTableData,
          PrefetchHooks Function()
        > {
  $$HistoryPartsTableTableTableManager(
    _$ChatHistoryDatabase db,
    $HistoryPartsTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$HistoryPartsTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$HistoryPartsTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$HistoryPartsTableTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> sessionId = const Value.absent(),
                Value<String> messageId = const Value.absent(),
                Value<String> partId = const Value.absent(),
                Value<int> orderIndex = const Value.absent(),
                Value<String> partJson = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
              }) => HistoryPartsTableCompanion(
                sessionId: sessionId,
                messageId: messageId,
                partId: partId,
                orderIndex: orderIndex,
                partJson: partJson,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                required String sessionId,
                required String messageId,
                required String partId,
                required int orderIndex,
                required String partJson,
                required int updatedAt,
              }) => HistoryPartsTableCompanion.insert(
                sessionId: sessionId,
                messageId: messageId,
                partId: partId,
                orderIndex: orderIndex,
                partJson: partJson,
                updatedAt: updatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$HistoryPartsTableTableProcessedTableManager =
    ProcessedTableManager<
      _$ChatHistoryDatabase,
      $HistoryPartsTableTable,
      HistoryPartsTableData,
      $$HistoryPartsTableTableFilterComposer,
      $$HistoryPartsTableTableOrderingComposer,
      $$HistoryPartsTableTableAnnotationComposer,
      $$HistoryPartsTableTableCreateCompanionBuilder,
      $$HistoryPartsTableTableUpdateCompanionBuilder,
      (
        HistoryPartsTableData,
        BaseReferences<
          _$ChatHistoryDatabase,
          $HistoryPartsTableTable,
          HistoryPartsTableData
        >,
      ),
      HistoryPartsTableData,
      PrefetchHooks Function()
    >;
typedef $$HistorySyncStateTableTableCreateCompanionBuilder =
    HistorySyncStateTableCompanion Function({
      required String sessionId,
      required int watermark,
      required int backendActivityAt,
      Value<int?> syncedAt,
    });
typedef $$HistorySyncStateTableTableUpdateCompanionBuilder =
    HistorySyncStateTableCompanion Function({
      Value<String> sessionId,
      Value<int> watermark,
      Value<int> backendActivityAt,
      Value<int?> syncedAt,
    });

class $$HistorySyncStateTableTableFilterComposer
    extends Composer<_$ChatHistoryDatabase, $HistorySyncStateTableTable> {
  $$HistorySyncStateTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get sessionId => $composableBuilder(
    column: $table.sessionId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get watermark => $composableBuilder(
    column: $table.watermark,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get backendActivityAt => $composableBuilder(
    column: $table.backendActivityAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get syncedAt => $composableBuilder(
    column: $table.syncedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$HistorySyncStateTableTableOrderingComposer
    extends Composer<_$ChatHistoryDatabase, $HistorySyncStateTableTable> {
  $$HistorySyncStateTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get sessionId => $composableBuilder(
    column: $table.sessionId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get watermark => $composableBuilder(
    column: $table.watermark,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get backendActivityAt => $composableBuilder(
    column: $table.backendActivityAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get syncedAt => $composableBuilder(
    column: $table.syncedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$HistorySyncStateTableTableAnnotationComposer
    extends Composer<_$ChatHistoryDatabase, $HistorySyncStateTableTable> {
  $$HistorySyncStateTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get sessionId =>
      $composableBuilder(column: $table.sessionId, builder: (column) => column);

  GeneratedColumn<int> get watermark =>
      $composableBuilder(column: $table.watermark, builder: (column) => column);

  GeneratedColumn<int> get backendActivityAt => $composableBuilder(
    column: $table.backendActivityAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get syncedAt =>
      $composableBuilder(column: $table.syncedAt, builder: (column) => column);
}

class $$HistorySyncStateTableTableTableManager
    extends
        RootTableManager<
          _$ChatHistoryDatabase,
          $HistorySyncStateTableTable,
          HistorySyncStateTableData,
          $$HistorySyncStateTableTableFilterComposer,
          $$HistorySyncStateTableTableOrderingComposer,
          $$HistorySyncStateTableTableAnnotationComposer,
          $$HistorySyncStateTableTableCreateCompanionBuilder,
          $$HistorySyncStateTableTableUpdateCompanionBuilder,
          (
            HistorySyncStateTableData,
            BaseReferences<
              _$ChatHistoryDatabase,
              $HistorySyncStateTableTable,
              HistorySyncStateTableData
            >,
          ),
          HistorySyncStateTableData,
          PrefetchHooks Function()
        > {
  $$HistorySyncStateTableTableTableManager(
    _$ChatHistoryDatabase db,
    $HistorySyncStateTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$HistorySyncStateTableTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$HistorySyncStateTableTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$HistorySyncStateTableTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> sessionId = const Value.absent(),
                Value<int> watermark = const Value.absent(),
                Value<int> backendActivityAt = const Value.absent(),
                Value<int?> syncedAt = const Value.absent(),
              }) => HistorySyncStateTableCompanion(
                sessionId: sessionId,
                watermark: watermark,
                backendActivityAt: backendActivityAt,
                syncedAt: syncedAt,
              ),
          createCompanionCallback:
              ({
                required String sessionId,
                required int watermark,
                required int backendActivityAt,
                Value<int?> syncedAt = const Value.absent(),
              }) => HistorySyncStateTableCompanion.insert(
                sessionId: sessionId,
                watermark: watermark,
                backendActivityAt: backendActivityAt,
                syncedAt: syncedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$HistorySyncStateTableTableProcessedTableManager =
    ProcessedTableManager<
      _$ChatHistoryDatabase,
      $HistorySyncStateTableTable,
      HistorySyncStateTableData,
      $$HistorySyncStateTableTableFilterComposer,
      $$HistorySyncStateTableTableOrderingComposer,
      $$HistorySyncStateTableTableAnnotationComposer,
      $$HistorySyncStateTableTableCreateCompanionBuilder,
      $$HistorySyncStateTableTableUpdateCompanionBuilder,
      (
        HistorySyncStateTableData,
        BaseReferences<
          _$ChatHistoryDatabase,
          $HistorySyncStateTableTable,
          HistorySyncStateTableData
        >,
      ),
      HistorySyncStateTableData,
      PrefetchHooks Function()
    >;

class $ChatHistoryDatabaseManager {
  final _$ChatHistoryDatabase _db;
  $ChatHistoryDatabaseManager(this._db);
  $$HistoryMessagesTableTableTableManager get historyMessagesTable =>
      $$HistoryMessagesTableTableTableManager(_db, _db.historyMessagesTable);
  $$HistoryPartsTableTableTableManager get historyPartsTable =>
      $$HistoryPartsTableTableTableManager(_db, _db.historyPartsTable);
  $$HistorySyncStateTableTableTableManager get historySyncStateTable =>
      $$HistorySyncStateTableTableTableManager(_db, _db.historySyncStateTable);
}
