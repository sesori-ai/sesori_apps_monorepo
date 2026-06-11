// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';
import 'session_error_unknown.dart';

@immutable
class SyncEventSessionNextToolFailed {
  const SyncEventSessionNextToolFailed({
    required this.type,
    required this.id,
    required this.syncEvent,
  });

  factory SyncEventSessionNextToolFailed.fromJson(Map<String, dynamic> json) {
    return SyncEventSessionNextToolFailed(
      type: json["type"] as String,
      id: json["id"] as String,
      syncEvent: SyncEventSessionNextToolFailedSyncEvent.fromJson(json["syncEvent"] as Map<String, dynamic>),
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
      (other is SyncEventSessionNextToolFailed &&
          other.type == type &&
          other.id == id &&
          other.syncEvent == syncEvent);

  @override
  int get hashCode => Object.hash(type, id, syncEvent);

  final String type;
  final String id;
  final SyncEventSessionNextToolFailedSyncEvent syncEvent;
}

@immutable
class SyncEventSessionNextToolFailedSyncEvent {
  const SyncEventSessionNextToolFailedSyncEvent({
    required this.type,
    required this.id,
    required this.seq,
    required this.aggregateID,
    required this.data,
  });

  factory SyncEventSessionNextToolFailedSyncEvent.fromJson(Map<String, dynamic> json) {
    return SyncEventSessionNextToolFailedSyncEvent(
      type: json["type"] as String,
      id: json["id"] as String,
      seq: (json["seq"] as num).toDouble(),
      aggregateID: json["aggregateID"] as String,
      data: SyncEventSessionNextToolFailedSyncEventData.fromJson(json["data"] as Map<String, dynamic>),
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
      (other is SyncEventSessionNextToolFailedSyncEvent &&
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
  final SyncEventSessionNextToolFailedSyncEventData data;
}

@immutable
class SyncEventSessionNextToolFailedSyncEventData {
  const SyncEventSessionNextToolFailedSyncEventData({
    required this.timestamp,
    required this.sessionID,
    required this.assistantMessageID,
    required this.callID,
    required this.error,
    this.result,
    required this.provider,
  });

  factory SyncEventSessionNextToolFailedSyncEventData.fromJson(Map<String, dynamic> json) {
    return SyncEventSessionNextToolFailedSyncEventData(
      timestamp: (json["timestamp"] as num).toDouble(),
      sessionID: json["sessionID"] as String,
      assistantMessageID: json["assistantMessageID"] as String,
      callID: json["callID"] as String,
      error: SessionErrorUnknown.fromJson(json["error"] as Map<String, dynamic>),
      result: json["result"] as Object?,
      provider: SyncEventSessionNextToolFailedSyncEventDataProvider.fromJson(json["provider"] as Map<String, dynamic>),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "timestamp": timestamp,
      "sessionID": sessionID,
      "assistantMessageID": assistantMessageID,
      "callID": callID,
      "error": error.toJson(),
      "result": ?result,
      "provider": provider.toJson(),
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncEventSessionNextToolFailedSyncEventData &&
          other.timestamp == timestamp &&
          other.sessionID == sessionID &&
          other.assistantMessageID == assistantMessageID &&
          other.callID == callID &&
          other.error == error &&
          const DeepCollectionEquality().equals(other.result, result) &&
          other.provider == provider);

  @override
  int get hashCode => Object.hash(timestamp, sessionID, assistantMessageID, callID, error, const DeepCollectionEquality().hash(result), provider);

  final double timestamp;
  final String sessionID;
  final String assistantMessageID;
  final String callID;
  final SessionErrorUnknown error;
  final Object? result;
  final SyncEventSessionNextToolFailedSyncEventDataProvider provider;
}

@immutable
class SyncEventSessionNextToolFailedSyncEventDataProvider {
  const SyncEventSessionNextToolFailedSyncEventDataProvider({
    required this.executed,
    this.metadata,
  });

  factory SyncEventSessionNextToolFailedSyncEventDataProvider.fromJson(Map<String, dynamic> json) {
    return SyncEventSessionNextToolFailedSyncEventDataProvider(
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
      (other is SyncEventSessionNextToolFailedSyncEventDataProvider &&
          other.executed == executed &&
          const DeepCollectionEquality().equals(other.metadata, metadata));

  @override
  int get hashCode => Object.hash(executed, const DeepCollectionEquality().hash(metadata));

  final bool executed;
  final Map<String, Map<String, dynamic>>? metadata;
}
