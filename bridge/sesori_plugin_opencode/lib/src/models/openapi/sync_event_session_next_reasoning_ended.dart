// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

@immutable
class SyncEventSessionNextReasoningEnded {
  const SyncEventSessionNextReasoningEnded({
    required this.type,
    required this.id,
    required this.syncEvent,
  });

  factory SyncEventSessionNextReasoningEnded.fromJson(Map<String, dynamic> json) {
    return SyncEventSessionNextReasoningEnded(
      type: json["type"] as String,
      id: json["id"] as String,
      syncEvent: SyncEventSessionNextReasoningEndedSyncEvent.fromJson(json["syncEvent"] as Map<String, dynamic>),
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
      (other is SyncEventSessionNextReasoningEnded &&
          other.type == type &&
          other.id == id &&
          other.syncEvent == syncEvent);

  @override
  int get hashCode => Object.hash(type, id, syncEvent);

  final String type;
  final String id;
  final SyncEventSessionNextReasoningEndedSyncEvent syncEvent;
}

@immutable
class SyncEventSessionNextReasoningEndedSyncEvent {
  const SyncEventSessionNextReasoningEndedSyncEvent({
    required this.type,
    required this.id,
    required this.seq,
    required this.aggregateID,
    required this.data,
  });

  factory SyncEventSessionNextReasoningEndedSyncEvent.fromJson(Map<String, dynamic> json) {
    return SyncEventSessionNextReasoningEndedSyncEvent(
      type: json["type"] as String,
      id: json["id"] as String,
      seq: (json["seq"] as num).toDouble(),
      aggregateID: json["aggregateID"] as String,
      data: SyncEventSessionNextReasoningEndedSyncEventData.fromJson(json["data"] as Map<String, dynamic>),
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
      (other is SyncEventSessionNextReasoningEndedSyncEvent &&
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
  final SyncEventSessionNextReasoningEndedSyncEventData data;
}

@immutable
class SyncEventSessionNextReasoningEndedSyncEventData {
  const SyncEventSessionNextReasoningEndedSyncEventData({
    required this.timestamp,
    required this.sessionID,
    required this.assistantMessageID,
    required this.reasoningID,
    required this.text,
    this.providerMetadata,
  });

  factory SyncEventSessionNextReasoningEndedSyncEventData.fromJson(Map<String, dynamic> json) {
    return SyncEventSessionNextReasoningEndedSyncEventData(
      timestamp: (json["timestamp"] as num).toDouble(),
      sessionID: json["sessionID"] as String,
      assistantMessageID: json["assistantMessageID"] as String,
      reasoningID: json["reasoningID"] as String,
      text: json["text"] as String,
      providerMetadata: (json["providerMetadata"] as Map<String, dynamic>?)?.map((k, v) => MapEntry(k, v as Map<String, dynamic>)),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "timestamp": timestamp,
      "sessionID": sessionID,
      "assistantMessageID": assistantMessageID,
      "reasoningID": reasoningID,
      "text": text,
      "providerMetadata": ?providerMetadata,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncEventSessionNextReasoningEndedSyncEventData &&
          other.timestamp == timestamp &&
          other.sessionID == sessionID &&
          other.assistantMessageID == assistantMessageID &&
          other.reasoningID == reasoningID &&
          other.text == text &&
          const DeepCollectionEquality().equals(other.providerMetadata, providerMetadata));

  @override
  int get hashCode => Object.hash(timestamp, sessionID, assistantMessageID, reasoningID, text, const DeepCollectionEquality().hash(providerMetadata));

  final double timestamp;
  final String sessionID;
  final String assistantMessageID;
  final String reasoningID;
  final String text;
  final Map<String, Map<String, dynamic>>? providerMetadata;
}
