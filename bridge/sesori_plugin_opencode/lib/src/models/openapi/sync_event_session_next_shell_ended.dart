// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)

import 'package:meta/meta.dart';

@immutable
class SyncEventSessionNextShellEnded {
  const SyncEventSessionNextShellEnded({
    required this.type,
    required this.id,
    required this.syncEvent,
  });

  factory SyncEventSessionNextShellEnded.fromJson(Map<String, dynamic> json) {
    return SyncEventSessionNextShellEnded(
      type: json["type"] as String,
      id: json["id"] as String,
      syncEvent: SyncEventSessionNextShellEndedSyncEvent.fromJson(json["syncEvent"] as Map<String, dynamic>),
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
      (other is SyncEventSessionNextShellEnded &&
          other.type == type &&
          other.id == id &&
          other.syncEvent == syncEvent);

  @override
  int get hashCode => Object.hash(type, id, syncEvent);

  final String type;
  final String id;
  final SyncEventSessionNextShellEndedSyncEvent syncEvent;
}

@immutable
class SyncEventSessionNextShellEndedSyncEvent {
  const SyncEventSessionNextShellEndedSyncEvent({
    required this.type,
    required this.id,
    required this.seq,
    required this.aggregateID,
    required this.data,
  });

  factory SyncEventSessionNextShellEndedSyncEvent.fromJson(Map<String, dynamic> json) {
    return SyncEventSessionNextShellEndedSyncEvent(
      type: json["type"] as String,
      id: json["id"] as String,
      seq: (json["seq"] as num).toDouble(),
      aggregateID: json["aggregateID"] as String,
      data: SyncEventSessionNextShellEndedSyncEventData.fromJson(json["data"] as Map<String, dynamic>),
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
      (other is SyncEventSessionNextShellEndedSyncEvent &&
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
  final SyncEventSessionNextShellEndedSyncEventData data;
}

@immutable
class SyncEventSessionNextShellEndedSyncEventData {
  const SyncEventSessionNextShellEndedSyncEventData({
    required this.timestamp,
    required this.sessionID,
    required this.callID,
    required this.output,
  });

  factory SyncEventSessionNextShellEndedSyncEventData.fromJson(Map<String, dynamic> json) {
    return SyncEventSessionNextShellEndedSyncEventData(
      timestamp: (json["timestamp"] as num).toDouble(),
      sessionID: json["sessionID"] as String,
      callID: json["callID"] as String,
      output: json["output"] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "timestamp": timestamp,
      "sessionID": sessionID,
      "callID": callID,
      "output": output,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncEventSessionNextShellEndedSyncEventData &&
          other.timestamp == timestamp &&
          other.sessionID == sessionID &&
          other.callID == callID &&
          other.output == output);

  @override
  int get hashCode => Object.hash(timestamp, sessionID, callID, output);

  final double timestamp;
  final String sessionID;
  final String callID;
  final String output;
}
