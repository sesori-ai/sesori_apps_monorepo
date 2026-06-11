// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

@immutable
class SyncEventSessionNextReasoningStarted {
  const SyncEventSessionNextReasoningStarted({
    required this.type,
    required this.id,
    required this.syncEvent,
  });

  factory SyncEventSessionNextReasoningStarted.fromJson(Map<String, dynamic> json) {
    return SyncEventSessionNextReasoningStarted(
      type: json["type"] as String,
      id: json["id"] as String,
      syncEvent: SyncEventSessionNextReasoningStartedSyncEvent.fromJson(json["syncEvent"] as Map<String, dynamic>),
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
      (other is SyncEventSessionNextReasoningStarted &&
          other.type == type &&
          other.id == id &&
          other.syncEvent == syncEvent);

  @override
  int get hashCode => Object.hash(type, id, syncEvent);

  final String type;
  final String id;
  final SyncEventSessionNextReasoningStartedSyncEvent syncEvent;
}

@immutable
class SyncEventSessionNextReasoningStartedSyncEvent {
  const SyncEventSessionNextReasoningStartedSyncEvent({
    required this.type,
    required this.id,
    required this.seq,
    required this.aggregateID,
    required this.data,
  });

  factory SyncEventSessionNextReasoningStartedSyncEvent.fromJson(Map<String, dynamic> json) {
    return SyncEventSessionNextReasoningStartedSyncEvent(
      type: json["type"] as String,
      id: json["id"] as String,
      seq: (json["seq"] as num).toDouble(),
      aggregateID: json["aggregateID"] as String,
      data: SyncEventSessionNextReasoningStartedSyncEventData.fromJson(json["data"] as Map<String, dynamic>),
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
      (other is SyncEventSessionNextReasoningStartedSyncEvent &&
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
  final SyncEventSessionNextReasoningStartedSyncEventData data;
}

@immutable
class SyncEventSessionNextReasoningStartedSyncEventData {
  const SyncEventSessionNextReasoningStartedSyncEventData({
    required this.timestamp,
    required this.sessionID,
    required this.assistantMessageID,
    required this.reasoningID,
    this.providerMetadata,
  });

  factory SyncEventSessionNextReasoningStartedSyncEventData.fromJson(Map<String, dynamic> json) {
    return SyncEventSessionNextReasoningStartedSyncEventData(
      timestamp: (json["timestamp"] as num).toDouble(),
      sessionID: json["sessionID"] as String,
      assistantMessageID: json["assistantMessageID"] as String,
      reasoningID: json["reasoningID"] as String,
      providerMetadata: (json["providerMetadata"] as Map<String, dynamic>?)?.map((k, v) => MapEntry(k, v as Map<String, dynamic>)),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "timestamp": timestamp,
      "sessionID": sessionID,
      "assistantMessageID": assistantMessageID,
      "reasoningID": reasoningID,
      "providerMetadata": ?providerMetadata,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncEventSessionNextReasoningStartedSyncEventData &&
          other.timestamp == timestamp &&
          other.sessionID == sessionID &&
          other.assistantMessageID == assistantMessageID &&
          other.reasoningID == reasoningID &&
          const DeepCollectionEquality().equals(other.providerMetadata, providerMetadata));

  @override
  int get hashCode => Object.hash(timestamp, sessionID, assistantMessageID, reasoningID, const DeepCollectionEquality().hash(providerMetadata));

  final double timestamp;
  final String sessionID;
  final String assistantMessageID;
  final String reasoningID;
  final Map<String, Map<String, dynamic>>? providerMetadata;
}
