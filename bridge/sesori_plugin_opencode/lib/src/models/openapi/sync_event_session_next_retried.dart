// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)

import 'package:meta/meta.dart';
import 'session_next_retry_error.dart';

@immutable
class SyncEventSessionNextRetried {
  const SyncEventSessionNextRetried({
    required this.type,
    required this.id,
    required this.syncEvent,
  });

  factory SyncEventSessionNextRetried.fromJson(Map<String, dynamic> json) {
    return SyncEventSessionNextRetried(
      type: json["type"] as String,
      id: json["id"] as String,
      syncEvent: SyncEventSessionNextRetriedSyncEvent.fromJson(json["syncEvent"] as Map<String, dynamic>),
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
      (other is SyncEventSessionNextRetried &&
          other.type == type &&
          other.id == id &&
          other.syncEvent == syncEvent);

  @override
  int get hashCode => Object.hash(type, id, syncEvent);

  final String type;
  final String id;
  final SyncEventSessionNextRetriedSyncEvent syncEvent;
}

@immutable
class SyncEventSessionNextRetriedSyncEvent {
  const SyncEventSessionNextRetriedSyncEvent({
    required this.type,
    required this.id,
    required this.seq,
    required this.aggregateID,
    required this.data,
  });

  factory SyncEventSessionNextRetriedSyncEvent.fromJson(Map<String, dynamic> json) {
    return SyncEventSessionNextRetriedSyncEvent(
      type: json["type"] as String,
      id: json["id"] as String,
      seq: (json["seq"] as num).toDouble(),
      aggregateID: json["aggregateID"] as String,
      data: SyncEventSessionNextRetriedSyncEventData.fromJson(json["data"] as Map<String, dynamic>),
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
      (other is SyncEventSessionNextRetriedSyncEvent &&
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
  final SyncEventSessionNextRetriedSyncEventData data;
}

@immutable
class SyncEventSessionNextRetriedSyncEventData {
  const SyncEventSessionNextRetriedSyncEventData({
    required this.timestamp,
    required this.sessionID,
    required this.attempt,
    required this.error,
  });

  factory SyncEventSessionNextRetriedSyncEventData.fromJson(Map<String, dynamic> json) {
    return SyncEventSessionNextRetriedSyncEventData(
      timestamp: (json["timestamp"] as num).toDouble(),
      sessionID: json["sessionID"] as String,
      attempt: (json["attempt"] as num).toDouble(),
      error: SessionNextRetryError.fromJson(json["error"] as Map<String, dynamic>),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "timestamp": timestamp,
      "sessionID": sessionID,
      "attempt": attempt,
      "error": error.toJson(),
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncEventSessionNextRetriedSyncEventData &&
          other.timestamp == timestamp &&
          other.sessionID == sessionID &&
          other.attempt == attempt &&
          other.error == error);

  @override
  int get hashCode => Object.hash(timestamp, sessionID, attempt, error);

  final double timestamp;
  final String sessionID;
  final double attempt;
  final SessionNextRetryError error;
}
