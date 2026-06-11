// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)

import 'package:meta/meta.dart';

@immutable
class SyncEventSessionNextAgentSwitched {
  const SyncEventSessionNextAgentSwitched({
    required this.type,
    required this.id,
    required this.syncEvent,
  });

  factory SyncEventSessionNextAgentSwitched.fromJson(Map<String, dynamic> json) {
    return SyncEventSessionNextAgentSwitched(
      type: json["type"] as String,
      id: json["id"] as String,
      syncEvent: SyncEventSessionNextAgentSwitchedSyncEvent.fromJson(json["syncEvent"] as Map<String, dynamic>),
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
      (other is SyncEventSessionNextAgentSwitched &&
          other.type == type &&
          other.id == id &&
          other.syncEvent == syncEvent);

  @override
  int get hashCode => Object.hash(type, id, syncEvent);

  final String type;
  final String id;
  final SyncEventSessionNextAgentSwitchedSyncEvent syncEvent;
}

@immutable
class SyncEventSessionNextAgentSwitchedSyncEvent {
  const SyncEventSessionNextAgentSwitchedSyncEvent({
    required this.type,
    required this.id,
    required this.seq,
    required this.aggregateID,
    required this.data,
  });

  factory SyncEventSessionNextAgentSwitchedSyncEvent.fromJson(Map<String, dynamic> json) {
    return SyncEventSessionNextAgentSwitchedSyncEvent(
      type: json["type"] as String,
      id: json["id"] as String,
      seq: (json["seq"] as num).toDouble(),
      aggregateID: json["aggregateID"] as String,
      data: SyncEventSessionNextAgentSwitchedSyncEventData.fromJson(json["data"] as Map<String, dynamic>),
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
      (other is SyncEventSessionNextAgentSwitchedSyncEvent &&
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
  final SyncEventSessionNextAgentSwitchedSyncEventData data;
}

@immutable
class SyncEventSessionNextAgentSwitchedSyncEventData {
  const SyncEventSessionNextAgentSwitchedSyncEventData({
    required this.timestamp,
    required this.sessionID,
    required this.messageID,
    required this.agent,
  });

  factory SyncEventSessionNextAgentSwitchedSyncEventData.fromJson(Map<String, dynamic> json) {
    return SyncEventSessionNextAgentSwitchedSyncEventData(
      timestamp: (json["timestamp"] as num).toDouble(),
      sessionID: json["sessionID"] as String,
      messageID: json["messageID"] as String,
      agent: json["agent"] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "timestamp": timestamp,
      "sessionID": sessionID,
      "messageID": messageID,
      "agent": agent,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncEventSessionNextAgentSwitchedSyncEventData &&
          other.timestamp == timestamp &&
          other.sessionID == sessionID &&
          other.messageID == messageID &&
          other.agent == agent);

  @override
  int get hashCode => Object.hash(timestamp, sessionID, messageID, agent);

  final double timestamp;
  final String sessionID;
  final String messageID;
  final String agent;
}
