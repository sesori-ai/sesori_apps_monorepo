// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)

import 'package:meta/meta.dart';

@immutable
class SyncEventSessionNextContextUpdated {
  const SyncEventSessionNextContextUpdated({
    required this.type,
    required this.id,
    required this.syncEvent,
  });

  factory SyncEventSessionNextContextUpdated.fromJson(Map<String, dynamic> json) {
    return SyncEventSessionNextContextUpdated(
      type: json["type"] as String,
      id: json["id"] as String,
      syncEvent: SyncEventSessionNextContextUpdatedSyncEvent.fromJson(json["syncEvent"] as Map<String, dynamic>),
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
      (other is SyncEventSessionNextContextUpdated &&
          other.type == type &&
          other.id == id &&
          other.syncEvent == syncEvent);

  @override
  int get hashCode => Object.hash(type, id, syncEvent);

  final String type;
  final String id;
  final SyncEventSessionNextContextUpdatedSyncEvent syncEvent;
}

@immutable
class SyncEventSessionNextContextUpdatedSyncEvent {
  const SyncEventSessionNextContextUpdatedSyncEvent({
    required this.type,
    required this.id,
    required this.seq,
    required this.aggregateID,
    required this.data,
  });

  factory SyncEventSessionNextContextUpdatedSyncEvent.fromJson(Map<String, dynamic> json) {
    return SyncEventSessionNextContextUpdatedSyncEvent(
      type: json["type"] as String,
      id: json["id"] as String,
      seq: (json["seq"] as num).toDouble(),
      aggregateID: json["aggregateID"] as String,
      data: SyncEventSessionNextContextUpdatedSyncEventData.fromJson(json["data"] as Map<String, dynamic>),
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
      (other is SyncEventSessionNextContextUpdatedSyncEvent &&
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
  final SyncEventSessionNextContextUpdatedSyncEventData data;
}

@immutable
class SyncEventSessionNextContextUpdatedSyncEventData {
  const SyncEventSessionNextContextUpdatedSyncEventData({
    required this.timestamp,
    required this.sessionID,
    required this.messageID,
    required this.text,
  });

  factory SyncEventSessionNextContextUpdatedSyncEventData.fromJson(Map<String, dynamic> json) {
    return SyncEventSessionNextContextUpdatedSyncEventData(
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
      (other is SyncEventSessionNextContextUpdatedSyncEventData &&
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
