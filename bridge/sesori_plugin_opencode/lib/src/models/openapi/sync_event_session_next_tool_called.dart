// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

@immutable
class SyncEventSessionNextToolCalled {
  const SyncEventSessionNextToolCalled({
    required this.type,
    required this.id,
    required this.syncEvent,
  });

  factory SyncEventSessionNextToolCalled.fromJson(Map<String, dynamic> json) {
    return SyncEventSessionNextToolCalled(
      type: json["type"] as String,
      id: json["id"] as String,
      syncEvent: SyncEventSessionNextToolCalledSyncEvent.fromJson(json["syncEvent"] as Map<String, dynamic>),
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
      (other is SyncEventSessionNextToolCalled &&
          other.type == type &&
          other.id == id &&
          other.syncEvent == syncEvent);

  @override
  int get hashCode => Object.hash(type, id, syncEvent);

  final String type;
  final String id;
  final SyncEventSessionNextToolCalledSyncEvent syncEvent;
}

@immutable
class SyncEventSessionNextToolCalledSyncEvent {
  const SyncEventSessionNextToolCalledSyncEvent({
    required this.type,
    required this.id,
    required this.seq,
    required this.aggregateID,
    required this.data,
  });

  factory SyncEventSessionNextToolCalledSyncEvent.fromJson(Map<String, dynamic> json) {
    return SyncEventSessionNextToolCalledSyncEvent(
      type: json["type"] as String,
      id: json["id"] as String,
      seq: (json["seq"] as num).toDouble(),
      aggregateID: json["aggregateID"] as String,
      data: SyncEventSessionNextToolCalledSyncEventData.fromJson(json["data"] as Map<String, dynamic>),
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
      (other is SyncEventSessionNextToolCalledSyncEvent &&
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
  final SyncEventSessionNextToolCalledSyncEventData data;
}

@immutable
class SyncEventSessionNextToolCalledSyncEventData {
  const SyncEventSessionNextToolCalledSyncEventData({
    required this.timestamp,
    required this.sessionID,
    required this.assistantMessageID,
    required this.callID,
    required this.tool,
    required this.input,
    required this.provider,
  });

  factory SyncEventSessionNextToolCalledSyncEventData.fromJson(Map<String, dynamic> json) {
    return SyncEventSessionNextToolCalledSyncEventData(
      timestamp: (json["timestamp"] as num).toDouble(),
      sessionID: json["sessionID"] as String,
      assistantMessageID: json["assistantMessageID"] as String,
      callID: json["callID"] as String,
      tool: json["tool"] as String,
      input: json["input"] as Map<String, dynamic>,
      provider: SyncEventSessionNextToolCalledSyncEventDataProvider.fromJson(json["provider"] as Map<String, dynamic>),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "timestamp": timestamp,
      "sessionID": sessionID,
      "assistantMessageID": assistantMessageID,
      "callID": callID,
      "tool": tool,
      "input": input,
      "provider": provider.toJson(),
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncEventSessionNextToolCalledSyncEventData &&
          other.timestamp == timestamp &&
          other.sessionID == sessionID &&
          other.assistantMessageID == assistantMessageID &&
          other.callID == callID &&
          other.tool == tool &&
          const DeepCollectionEquality().equals(other.input, input) &&
          other.provider == provider);

  @override
  int get hashCode => Object.hash(timestamp, sessionID, assistantMessageID, callID, tool, const DeepCollectionEquality().hash(input), provider);

  final double timestamp;
  final String sessionID;
  final String assistantMessageID;
  final String callID;
  final String tool;
  final Map<String, dynamic> input;
  final SyncEventSessionNextToolCalledSyncEventDataProvider provider;
}

@immutable
class SyncEventSessionNextToolCalledSyncEventDataProvider {
  const SyncEventSessionNextToolCalledSyncEventDataProvider({
    required this.executed,
    this.metadata,
  });

  factory SyncEventSessionNextToolCalledSyncEventDataProvider.fromJson(Map<String, dynamic> json) {
    return SyncEventSessionNextToolCalledSyncEventDataProvider(
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
      (other is SyncEventSessionNextToolCalledSyncEventDataProvider &&
          other.executed == executed &&
          const DeepCollectionEquality().equals(other.metadata, metadata));

  @override
  int get hashCode => Object.hash(executed, const DeepCollectionEquality().hash(metadata));

  final bool executed;
  final Map<String, Map<String, dynamic>>? metadata;
}
