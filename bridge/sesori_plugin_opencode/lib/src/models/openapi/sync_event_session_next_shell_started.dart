// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)

import 'package:meta/meta.dart';

@immutable
class SyncEventSessionNextShellStarted {
  const SyncEventSessionNextShellStarted({
    required this.type,
    required this.id,
    required this.syncEvent,
  });

  factory SyncEventSessionNextShellStarted.fromJson(Map<String, dynamic> json) {
    return SyncEventSessionNextShellStarted(
      type: json["type"] as String,
      id: json["id"] as String,
      syncEvent: SyncEventSessionNextShellStartedSyncEvent.fromJson(json["syncEvent"] as Map<String, dynamic>),
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
      (other is SyncEventSessionNextShellStarted &&
          other.type == type &&
          other.id == id &&
          other.syncEvent == syncEvent);

  @override
  int get hashCode => Object.hash(type, id, syncEvent);

  final String type;
  final String id;
  final SyncEventSessionNextShellStartedSyncEvent syncEvent;
}

@immutable
class SyncEventSessionNextShellStartedSyncEvent {
  const SyncEventSessionNextShellStartedSyncEvent({
    required this.type,
    required this.id,
    required this.seq,
    required this.aggregateID,
    required this.data,
  });

  factory SyncEventSessionNextShellStartedSyncEvent.fromJson(Map<String, dynamic> json) {
    return SyncEventSessionNextShellStartedSyncEvent(
      type: json["type"] as String,
      id: json["id"] as String,
      seq: (json["seq"] as num).toDouble(),
      aggregateID: json["aggregateID"] as String,
      data: SyncEventSessionNextShellStartedSyncEventData.fromJson(json["data"] as Map<String, dynamic>),
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
      (other is SyncEventSessionNextShellStartedSyncEvent &&
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
  final SyncEventSessionNextShellStartedSyncEventData data;
}

@immutable
class SyncEventSessionNextShellStartedSyncEventData {
  const SyncEventSessionNextShellStartedSyncEventData({
    required this.timestamp,
    required this.sessionID,
    required this.messageID,
    required this.callID,
    required this.command,
  });

  factory SyncEventSessionNextShellStartedSyncEventData.fromJson(Map<String, dynamic> json) {
    return SyncEventSessionNextShellStartedSyncEventData(
      timestamp: (json["timestamp"] as num).toDouble(),
      sessionID: json["sessionID"] as String,
      messageID: json["messageID"] as String,
      callID: json["callID"] as String,
      command: json["command"] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "timestamp": timestamp,
      "sessionID": sessionID,
      "messageID": messageID,
      "callID": callID,
      "command": command,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncEventSessionNextShellStartedSyncEventData &&
          other.timestamp == timestamp &&
          other.sessionID == sessionID &&
          other.messageID == messageID &&
          other.callID == callID &&
          other.command == command);

  @override
  int get hashCode => Object.hash(timestamp, sessionID, messageID, callID, command);

  final double timestamp;
  final String sessionID;
  final String messageID;
  final String callID;
  final String command;
}
