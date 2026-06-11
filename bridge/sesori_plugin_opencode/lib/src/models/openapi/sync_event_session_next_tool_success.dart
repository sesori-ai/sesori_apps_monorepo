// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

@immutable
class SyncEventSessionNextToolSuccess {
  const SyncEventSessionNextToolSuccess({
    required this.type,
    required this.id,
    required this.syncEvent,
  });

  factory SyncEventSessionNextToolSuccess.fromJson(Map<String, dynamic> json) {
    return SyncEventSessionNextToolSuccess(
      type: json["type"] as String,
      id: json["id"] as String,
      syncEvent: SyncEventSessionNextToolSuccessSyncEvent.fromJson(json["syncEvent"] as Map<String, dynamic>),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "type": type,
      "id": id,
      "syncEvent": syncEvent.toJson(),
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncEventSessionNextToolSuccess &&
          other.type == type &&
          other.id == id &&
          other.syncEvent == syncEvent);

  @override
  int get hashCode => Object.hash(type, id, syncEvent);

  final String type;
  final String id;
  final SyncEventSessionNextToolSuccessSyncEvent syncEvent;
}

@immutable
class SyncEventSessionNextToolSuccessSyncEvent {
  const SyncEventSessionNextToolSuccessSyncEvent({
    required this.type,
    required this.id,
    required this.seq,
    required this.aggregateID,
    required this.data,
  });

  factory SyncEventSessionNextToolSuccessSyncEvent.fromJson(Map<String, dynamic> json) {
    return SyncEventSessionNextToolSuccessSyncEvent(
      type: json["type"] as String,
      id: json["id"] as String,
      seq: (json["seq"] as num).toDouble(),
      aggregateID: json["aggregateID"] as String,
      data: SyncEventSessionNextToolSuccessSyncEventData.fromJson(json["data"] as Map<String, dynamic>),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "type": type,
      "id": id,
      "seq": seq,
      "aggregateID": aggregateID,
      "data": data.toJson(),
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncEventSessionNextToolSuccessSyncEvent &&
          other.type == type &&
          other.id == id &&
          other.seq == seq &&
          other.aggregateID == aggregateID &&
          other.data == data);

  @override
  int get hashCode => Object.hash(type, id, seq, aggregateID, data);

  final String type;
  final String id;
  final double seq;
  final String aggregateID;
  final SyncEventSessionNextToolSuccessSyncEventData data;
}

@immutable
class SyncEventSessionNextToolSuccessSyncEventData {
  const SyncEventSessionNextToolSuccessSyncEventData({
    required this.timestamp,
    required this.sessionID,
    required this.assistantMessageID,
    required this.callID,
    required this.structured,
    required this.content,
    this.result,
    required this.provider,
  });

  factory SyncEventSessionNextToolSuccessSyncEventData.fromJson(Map<String, dynamic> json) {
    return SyncEventSessionNextToolSuccessSyncEventData(
      timestamp: (json["timestamp"] as num).toDouble(),
      sessionID: json["sessionID"] as String,
      assistantMessageID: json["assistantMessageID"] as String,
      callID: json["callID"] as String,
      structured: json["structured"] as Map<String, dynamic>,
      content: (json["content"] as List<dynamic>).cast<Object>(),
      result: json["result"] as Object?,
      provider: SyncEventSessionNextToolSuccessSyncEventDataProvider.fromJson(json["provider"] as Map<String, dynamic>),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "timestamp": timestamp,
      "sessionID": sessionID,
      "assistantMessageID": assistantMessageID,
      "callID": callID,
      "structured": structured,
      "content": content,
      "result": ?result,
      "provider": provider.toJson(),
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncEventSessionNextToolSuccessSyncEventData &&
          other.timestamp == timestamp &&
          other.sessionID == sessionID &&
          other.assistantMessageID == assistantMessageID &&
          other.callID == callID &&
          const DeepCollectionEquality().equals(other.structured, structured) &&
          const DeepCollectionEquality().equals(other.content, content) &&
          const DeepCollectionEquality().equals(other.result, result) &&
          other.provider == provider);

  @override
  int get hashCode => Object.hash(timestamp, sessionID, assistantMessageID, callID, const DeepCollectionEquality().hash(structured), const DeepCollectionEquality().hash(content), const DeepCollectionEquality().hash(result), provider);

  final double timestamp;
  final String sessionID;
  final String assistantMessageID;
  final String callID;
  final Map<String, dynamic> structured;
  final List<Object> content;
  final Object? result;
  final SyncEventSessionNextToolSuccessSyncEventDataProvider provider;
}

@immutable
class SyncEventSessionNextToolSuccessSyncEventDataProvider {
  const SyncEventSessionNextToolSuccessSyncEventDataProvider({
    required this.executed,
    this.metadata,
  });

  factory SyncEventSessionNextToolSuccessSyncEventDataProvider.fromJson(Map<String, dynamic> json) {
    return SyncEventSessionNextToolSuccessSyncEventDataProvider(
      executed: json["executed"] as bool,
      metadata: (json["metadata"] as Map<String, dynamic>?)?.map((k, v) => MapEntry(k, v as Map<String, dynamic>)),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "executed": executed,
      "metadata": ?metadata,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncEventSessionNextToolSuccessSyncEventDataProvider &&
          other.executed == executed &&
          const DeepCollectionEquality().equals(other.metadata, metadata));

  @override
  int get hashCode => Object.hash(executed, const DeepCollectionEquality().hash(metadata));

  final bool executed;
  final Map<String, Map<String, dynamic>>? metadata;
}
