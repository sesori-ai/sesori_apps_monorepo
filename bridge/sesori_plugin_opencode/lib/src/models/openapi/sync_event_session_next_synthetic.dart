// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)

import 'package:meta/meta.dart';

@immutable
class SyncEventSessionNextSynthetic {
  const SyncEventSessionNextSynthetic({
    required this.type,
    required this.id,
    required this.syncEvent,
  });

  factory SyncEventSessionNextSynthetic.fromJson(Map<String, dynamic> json) {
    return SyncEventSessionNextSynthetic(
      type: json["type"] as String,
      id: json["id"] as String,
      syncEvent: SyncEventSessionNextSyntheticSyncEvent.fromJson(json["syncEvent"] as Map<String, dynamic>),
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
      (other is SyncEventSessionNextSynthetic &&
          other.type == type &&
          other.id == id &&
          other.syncEvent == syncEvent);

  @override
  int get hashCode => Object.hash(type, id, syncEvent);

  final String type;
  final String id;
  final SyncEventSessionNextSyntheticSyncEvent syncEvent;
}

@immutable
class SyncEventSessionNextSyntheticSyncEvent {
  const SyncEventSessionNextSyntheticSyncEvent({
    required this.type,
    required this.id,
    required this.seq,
    required this.aggregateID,
    required this.data,
  });

  factory SyncEventSessionNextSyntheticSyncEvent.fromJson(Map<String, dynamic> json) {
    return SyncEventSessionNextSyntheticSyncEvent(
      type: json["type"] as String,
      id: json["id"] as String,
      seq: (json["seq"] as num).toDouble(),
      aggregateID: json["aggregateID"] as String,
      data: SyncEventSessionNextSyntheticSyncEventData.fromJson(json["data"] as Map<String, dynamic>),
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
      (other is SyncEventSessionNextSyntheticSyncEvent &&
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
  final SyncEventSessionNextSyntheticSyncEventData data;
}

@immutable
class SyncEventSessionNextSyntheticSyncEventData {
  const SyncEventSessionNextSyntheticSyncEventData({
    required this.timestamp,
    required this.sessionID,
    required this.messageID,
    required this.text,
  });

  factory SyncEventSessionNextSyntheticSyncEventData.fromJson(Map<String, dynamic> json) {
    return SyncEventSessionNextSyntheticSyncEventData(
      timestamp: (json["timestamp"] as num).toDouble(),
      sessionID: json["sessionID"] as String,
      messageID: json["messageID"] as String,
      text: json["text"] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "timestamp": timestamp,
      "sessionID": sessionID,
      "messageID": messageID,
      "text": text,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncEventSessionNextSyntheticSyncEventData &&
          other.timestamp == timestamp &&
          other.sessionID == sessionID &&
          other.messageID == messageID &&
          other.text == text);

  @override
  int get hashCode => Object.hash(timestamp, sessionID, messageID, text);

  final double timestamp;
  final String sessionID;
  final String messageID;
  final String text;
}
