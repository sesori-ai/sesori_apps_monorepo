// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)

import 'package:meta/meta.dart';

@immutable
class SyncEventSessionNextCompactionEnded {
  const SyncEventSessionNextCompactionEnded({
    required this.type,
    required this.id,
    required this.syncEvent,
  });

  factory SyncEventSessionNextCompactionEnded.fromJson(Map<String, dynamic> json) {
    return SyncEventSessionNextCompactionEnded(
      type: json["type"] as String,
      id: json["id"] as String,
      syncEvent: SyncEventSessionNextCompactionEndedSyncEvent.fromJson(json["syncEvent"] as Map<String, dynamic>),
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
      (other is SyncEventSessionNextCompactionEnded &&
          other.type == type &&
          other.id == id &&
          other.syncEvent == syncEvent);

  @override
  int get hashCode => Object.hash(type, id, syncEvent);

  final String type;
  final String id;
  final SyncEventSessionNextCompactionEndedSyncEvent syncEvent;
}

@immutable
class SyncEventSessionNextCompactionEndedSyncEvent {
  const SyncEventSessionNextCompactionEndedSyncEvent({
    required this.type,
    required this.id,
    required this.seq,
    required this.aggregateID,
    required this.data,
  });

  factory SyncEventSessionNextCompactionEndedSyncEvent.fromJson(Map<String, dynamic> json) {
    return SyncEventSessionNextCompactionEndedSyncEvent(
      type: json["type"] as String,
      id: json["id"] as String,
      seq: (json["seq"] as num).toDouble(),
      aggregateID: json["aggregateID"] as String,
      data: SyncEventSessionNextCompactionEndedSyncEventData.fromJson(json["data"] as Map<String, dynamic>),
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
      (other is SyncEventSessionNextCompactionEndedSyncEvent &&
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
  final SyncEventSessionNextCompactionEndedSyncEventData data;
}

@immutable
class SyncEventSessionNextCompactionEndedSyncEventData {
  const SyncEventSessionNextCompactionEndedSyncEventData({
    required this.timestamp,
    required this.sessionID,
    required this.text,
    this.include,
  });

  factory SyncEventSessionNextCompactionEndedSyncEventData.fromJson(Map<String, dynamic> json) {
    return SyncEventSessionNextCompactionEndedSyncEventData(
      timestamp: (json["timestamp"] as num).toDouble(),
      sessionID: json["sessionID"] as String,
      text: json["text"] as String,
      include: json["include"] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "timestamp": timestamp,
      "sessionID": sessionID,
      "text": text,
      "include": ?include,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncEventSessionNextCompactionEndedSyncEventData &&
          other.timestamp == timestamp &&
          other.sessionID == sessionID &&
          other.text == text &&
          other.include == include);

  @override
  int get hashCode => Object.hash(timestamp, sessionID, text, include);

  final double timestamp;
  final String sessionID;
  final String text;
  final String? include;
}
