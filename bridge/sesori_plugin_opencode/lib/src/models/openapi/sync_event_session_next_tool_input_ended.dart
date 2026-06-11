// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)

import 'package:meta/meta.dart';

@immutable
class SyncEventSessionNextToolInputEnded {
  const SyncEventSessionNextToolInputEnded({
    required this.type,
    required this.id,
    required this.syncEvent,
  });

  factory SyncEventSessionNextToolInputEnded.fromJson(Map<String, dynamic> json) {
    return SyncEventSessionNextToolInputEnded(
      type: json["type"] as String,
      id: json["id"] as String,
      syncEvent: SyncEventSessionNextToolInputEndedSyncEvent.fromJson(json["syncEvent"] as Map<String, dynamic>),
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
      (other is SyncEventSessionNextToolInputEnded &&
          other.type == type &&
          other.id == id &&
          other.syncEvent == syncEvent);

  @override
  int get hashCode => Object.hash(type, id, syncEvent);

  final String type;
  final String id;
  final SyncEventSessionNextToolInputEndedSyncEvent syncEvent;
}

@immutable
class SyncEventSessionNextToolInputEndedSyncEvent {
  const SyncEventSessionNextToolInputEndedSyncEvent({
    required this.type,
    required this.id,
    required this.seq,
    required this.aggregateID,
    required this.data,
  });

  factory SyncEventSessionNextToolInputEndedSyncEvent.fromJson(Map<String, dynamic> json) {
    return SyncEventSessionNextToolInputEndedSyncEvent(
      type: json["type"] as String,
      id: json["id"] as String,
      seq: (json["seq"] as num).toDouble(),
      aggregateID: json["aggregateID"] as String,
      data: SyncEventSessionNextToolInputEndedSyncEventData.fromJson(json["data"] as Map<String, dynamic>),
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
      (other is SyncEventSessionNextToolInputEndedSyncEvent &&
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
  final SyncEventSessionNextToolInputEndedSyncEventData data;
}

@immutable
class SyncEventSessionNextToolInputEndedSyncEventData {
  const SyncEventSessionNextToolInputEndedSyncEventData({
    required this.timestamp,
    required this.sessionID,
    required this.assistantMessageID,
    required this.callID,
    required this.text,
  });

  factory SyncEventSessionNextToolInputEndedSyncEventData.fromJson(Map<String, dynamic> json) {
    return SyncEventSessionNextToolInputEndedSyncEventData(
      timestamp: (json["timestamp"] as num).toDouble(),
      sessionID: json["sessionID"] as String,
      assistantMessageID: json["assistantMessageID"] as String,
      callID: json["callID"] as String,
      text: json["text"] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "timestamp": timestamp,
      "sessionID": sessionID,
      "assistantMessageID": assistantMessageID,
      "callID": callID,
      "text": text,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncEventSessionNextToolInputEndedSyncEventData &&
          other.timestamp == timestamp &&
          other.sessionID == sessionID &&
          other.assistantMessageID == assistantMessageID &&
          other.callID == callID &&
          other.text == text);

  @override
  int get hashCode => Object.hash(timestamp, sessionID, assistantMessageID, callID, text);

  final double timestamp;
  final String sessionID;
  final String assistantMessageID;
  final String callID;
  final String text;
}
