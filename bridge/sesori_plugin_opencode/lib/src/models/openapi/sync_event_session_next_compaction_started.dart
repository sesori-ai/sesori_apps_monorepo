// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)

import 'package:meta/meta.dart';

@immutable
class SyncEventSessionNextCompactionStarted {
  const SyncEventSessionNextCompactionStarted({
    required this.type,
    required this.id,
    required this.syncEvent,
  });

  factory SyncEventSessionNextCompactionStarted.fromJson(Map<String, dynamic> json) {
    return SyncEventSessionNextCompactionStarted(
      type: json["type"] as String,
      id: json["id"] as String,
      syncEvent: SyncEventSessionNextCompactionStartedSyncEvent.fromJson(json["syncEvent"] as Map<String, dynamic>),
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
      (other is SyncEventSessionNextCompactionStarted &&
          other.type == type &&
          other.id == id &&
          other.syncEvent == syncEvent);

  @override
  int get hashCode => Object.hash(type, id, syncEvent);

  final String type;
  final String id;
  final SyncEventSessionNextCompactionStartedSyncEvent syncEvent;
}

@immutable
class SyncEventSessionNextCompactionStartedSyncEvent {
  const SyncEventSessionNextCompactionStartedSyncEvent({
    required this.type,
    required this.id,
    required this.seq,
    required this.aggregateID,
    required this.data,
  });

  factory SyncEventSessionNextCompactionStartedSyncEvent.fromJson(Map<String, dynamic> json) {
    return SyncEventSessionNextCompactionStartedSyncEvent(
      type: json["type"] as String,
      id: json["id"] as String,
      seq: (json["seq"] as num).toDouble(),
      aggregateID: json["aggregateID"] as String,
      data: SyncEventSessionNextCompactionStartedSyncEventData.fromJson(json["data"] as Map<String, dynamic>),
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
      (other is SyncEventSessionNextCompactionStartedSyncEvent &&
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
  final SyncEventSessionNextCompactionStartedSyncEventData data;
}

@immutable
class SyncEventSessionNextCompactionStartedSyncEventData {
  const SyncEventSessionNextCompactionStartedSyncEventData({
    required this.timestamp,
    required this.sessionID,
    required this.messageID,
    required this.reason,
  });

  factory SyncEventSessionNextCompactionStartedSyncEventData.fromJson(Map<String, dynamic> json) {
    return SyncEventSessionNextCompactionStartedSyncEventData(
      timestamp: (json["timestamp"] as num).toDouble(),
      sessionID: json["sessionID"] as String,
      messageID: json["messageID"] as String,
      reason: json["reason"] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "timestamp": timestamp,
      "sessionID": sessionID,
      "messageID": messageID,
      "reason": reason,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncEventSessionNextCompactionStartedSyncEventData &&
          other.timestamp == timestamp &&
          other.sessionID == sessionID &&
          other.messageID == messageID &&
          other.reason == reason);

  @override
  int get hashCode => Object.hash(timestamp, sessionID, messageID, reason);

  final double timestamp;
  final String sessionID;
  final String messageID;
  final String reason;
}
