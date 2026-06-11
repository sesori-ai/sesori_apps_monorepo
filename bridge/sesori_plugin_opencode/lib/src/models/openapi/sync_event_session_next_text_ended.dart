// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)

import 'package:meta/meta.dart';

@immutable
class SyncEventSessionNextTextEnded {
  const SyncEventSessionNextTextEnded({
    required this.type,
    required this.id,
    required this.syncEvent,
  });

  factory SyncEventSessionNextTextEnded.fromJson(Map<String, dynamic> json) {
    return SyncEventSessionNextTextEnded(
      type: json["type"] as String,
      id: json["id"] as String,
      syncEvent: SyncEventSessionNextTextEndedSyncEvent.fromJson(json["syncEvent"] as Map<String, dynamic>),
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
      (other is SyncEventSessionNextTextEnded &&
          other.type == type &&
          other.id == id &&
          other.syncEvent == syncEvent);

  @override
  int get hashCode => Object.hash(type, id, syncEvent);

  final String type;
  final String id;
  final SyncEventSessionNextTextEndedSyncEvent syncEvent;
}

@immutable
class SyncEventSessionNextTextEndedSyncEvent {
  const SyncEventSessionNextTextEndedSyncEvent({
    required this.type,
    required this.id,
    required this.seq,
    required this.aggregateID,
    required this.data,
  });

  factory SyncEventSessionNextTextEndedSyncEvent.fromJson(Map<String, dynamic> json) {
    return SyncEventSessionNextTextEndedSyncEvent(
      type: json["type"] as String,
      id: json["id"] as String,
      seq: (json["seq"] as num).toDouble(),
      aggregateID: json["aggregateID"] as String,
      data: SyncEventSessionNextTextEndedSyncEventData.fromJson(json["data"] as Map<String, dynamic>),
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
      (other is SyncEventSessionNextTextEndedSyncEvent &&
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
  final SyncEventSessionNextTextEndedSyncEventData data;
}

@immutable
class SyncEventSessionNextTextEndedSyncEventData {
  const SyncEventSessionNextTextEndedSyncEventData({
    required this.timestamp,
    required this.sessionID,
    required this.assistantMessageID,
    required this.textID,
    required this.text,
  });

  factory SyncEventSessionNextTextEndedSyncEventData.fromJson(Map<String, dynamic> json) {
    return SyncEventSessionNextTextEndedSyncEventData(
      timestamp: (json["timestamp"] as num).toDouble(),
      sessionID: json["sessionID"] as String,
      assistantMessageID: json["assistantMessageID"] as String,
      textID: json["textID"] as String,
      text: json["text"] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "timestamp": timestamp,
      "sessionID": sessionID,
      "assistantMessageID": assistantMessageID,
      "textID": textID,
      "text": text,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncEventSessionNextTextEndedSyncEventData &&
          other.timestamp == timestamp &&
          other.sessionID == sessionID &&
          other.assistantMessageID == assistantMessageID &&
          other.textID == textID &&
          other.text == text);

  @override
  int get hashCode => Object.hash(timestamp, sessionID, assistantMessageID, textID, text);

  final double timestamp;
  final String sessionID;
  final String assistantMessageID;
  final String textID;
  final String text;
}
