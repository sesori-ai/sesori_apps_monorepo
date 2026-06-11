// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)

import 'package:meta/meta.dart';
import 'session_error_unknown.dart';

@immutable
class SyncEventSessionNextStepFailed {
  const SyncEventSessionNextStepFailed({
    required this.type,
    required this.id,
    required this.syncEvent,
  });

  factory SyncEventSessionNextStepFailed.fromJson(Map<String, dynamic> json) {
    return SyncEventSessionNextStepFailed(
      type: json["type"] as String,
      id: json["id"] as String,
      syncEvent: SyncEventSessionNextStepFailedSyncEvent.fromJson(json["syncEvent"] as Map<String, dynamic>),
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
      (other is SyncEventSessionNextStepFailed &&
          other.type == type &&
          other.id == id &&
          other.syncEvent == syncEvent);

  @override
  int get hashCode => Object.hash(type, id, syncEvent);

  final String type;
  final String id;
  final SyncEventSessionNextStepFailedSyncEvent syncEvent;
}

@immutable
class SyncEventSessionNextStepFailedSyncEvent {
  const SyncEventSessionNextStepFailedSyncEvent({
    required this.type,
    required this.id,
    required this.seq,
    required this.aggregateID,
    required this.data,
  });

  factory SyncEventSessionNextStepFailedSyncEvent.fromJson(Map<String, dynamic> json) {
    return SyncEventSessionNextStepFailedSyncEvent(
      type: json["type"] as String,
      id: json["id"] as String,
      seq: (json["seq"] as num).toDouble(),
      aggregateID: json["aggregateID"] as String,
      data: SyncEventSessionNextStepFailedSyncEventData.fromJson(json["data"] as Map<String, dynamic>),
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
      (other is SyncEventSessionNextStepFailedSyncEvent &&
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
  final SyncEventSessionNextStepFailedSyncEventData data;
}

@immutable
class SyncEventSessionNextStepFailedSyncEventData {
  const SyncEventSessionNextStepFailedSyncEventData({
    required this.timestamp,
    required this.sessionID,
    required this.assistantMessageID,
    required this.error,
  });

  factory SyncEventSessionNextStepFailedSyncEventData.fromJson(Map<String, dynamic> json) {
    return SyncEventSessionNextStepFailedSyncEventData(
      timestamp: (json["timestamp"] as num).toDouble(),
      sessionID: json["sessionID"] as String,
      assistantMessageID: json["assistantMessageID"] as String,
      error: SessionErrorUnknown.fromJson(json["error"] as Map<String, dynamic>),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "timestamp": timestamp,
      "sessionID": sessionID,
      "assistantMessageID": assistantMessageID,
      "error": error.toJson(),
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncEventSessionNextStepFailedSyncEventData &&
          other.timestamp == timestamp &&
          other.sessionID == sessionID &&
          other.assistantMessageID == assistantMessageID &&
          other.error == error);

  @override
  int get hashCode => Object.hash(timestamp, sessionID, assistantMessageID, error);

  final double timestamp;
  final String sessionID;
  final String assistantMessageID;
  final SessionErrorUnknown error;
}
