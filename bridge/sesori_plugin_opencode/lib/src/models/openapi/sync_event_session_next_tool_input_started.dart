// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)

import 'package:meta/meta.dart';

@immutable
class SyncEventSessionNextToolInputStarted {
  const SyncEventSessionNextToolInputStarted({
    required this.type,
    required this.id,
    required this.syncEvent,
  });

  factory SyncEventSessionNextToolInputStarted.fromJson(Map<String, dynamic> json) {
    return SyncEventSessionNextToolInputStarted(
      type: json["type"] as String,
      id: json["id"] as String,
      syncEvent: SyncEventSessionNextToolInputStartedSyncEvent.fromJson(json["syncEvent"] as Map<String, dynamic>),
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
      (other is SyncEventSessionNextToolInputStarted &&
          other.type == type &&
          other.id == id &&
          other.syncEvent == syncEvent);

  @override
  int get hashCode => Object.hash(type, id, syncEvent);

  final String type;
  final String id;
  final SyncEventSessionNextToolInputStartedSyncEvent syncEvent;
}

@immutable
class SyncEventSessionNextToolInputStartedSyncEvent {
  const SyncEventSessionNextToolInputStartedSyncEvent({
    required this.type,
    required this.id,
    required this.seq,
    required this.aggregateID,
    required this.data,
  });

  factory SyncEventSessionNextToolInputStartedSyncEvent.fromJson(Map<String, dynamic> json) {
    return SyncEventSessionNextToolInputStartedSyncEvent(
      type: json["type"] as String,
      id: json["id"] as String,
      seq: (json["seq"] as num).toDouble(),
      aggregateID: json["aggregateID"] as String,
      data: SyncEventSessionNextToolInputStartedSyncEventData.fromJson(json["data"] as Map<String, dynamic>),
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
      (other is SyncEventSessionNextToolInputStartedSyncEvent &&
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
  final SyncEventSessionNextToolInputStartedSyncEventData data;
}

@immutable
class SyncEventSessionNextToolInputStartedSyncEventData {
  const SyncEventSessionNextToolInputStartedSyncEventData({
    required this.timestamp,
    required this.sessionID,
    required this.assistantMessageID,
    required this.callID,
    required this.name,
  });

  factory SyncEventSessionNextToolInputStartedSyncEventData.fromJson(Map<String, dynamic> json) {
    return SyncEventSessionNextToolInputStartedSyncEventData(
      timestamp: (json["timestamp"] as num).toDouble(),
      sessionID: json["sessionID"] as String,
      assistantMessageID: json["assistantMessageID"] as String,
      callID: json["callID"] as String,
      name: json["name"] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "timestamp": timestamp,
      "sessionID": sessionID,
      "assistantMessageID": assistantMessageID,
      "callID": callID,
      "name": name,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncEventSessionNextToolInputStartedSyncEventData &&
          other.timestamp == timestamp &&
          other.sessionID == sessionID &&
          other.assistantMessageID == assistantMessageID &&
          other.callID == callID &&
          other.name == name);

  @override
  int get hashCode => Object.hash(timestamp, sessionID, assistantMessageID, callID, name);

  final double timestamp;
  final String sessionID;
  final String assistantMessageID;
  final String callID;
  final String name;
}
