// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)

import 'package:meta/meta.dart';

@immutable
class SyncEventSessionNextCompactionDelta {
  const SyncEventSessionNextCompactionDelta({
    required this.type,
    required this.id,
    required this.syncEvent,
  });

  factory SyncEventSessionNextCompactionDelta.fromJson(Map<String, dynamic> json) {
    return SyncEventSessionNextCompactionDelta(
      type: json["type"] as String,
      id: json["id"] as String,
      syncEvent: SyncEventSessionNextCompactionDeltaSyncEvent.fromJson(json["syncEvent"] as Map<String, dynamic>),
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
      (other is SyncEventSessionNextCompactionDelta &&
          other.type == type &&
          other.id == id &&
          other.syncEvent == syncEvent);

  @override
  int get hashCode => Object.hash(type, id, syncEvent);

  final String type;
  final String id;
  final SyncEventSessionNextCompactionDeltaSyncEvent syncEvent;
}

@immutable
class SyncEventSessionNextCompactionDeltaSyncEvent {
  const SyncEventSessionNextCompactionDeltaSyncEvent({
    required this.type,
    required this.id,
    required this.seq,
    required this.aggregateID,
    required this.data,
  });

  factory SyncEventSessionNextCompactionDeltaSyncEvent.fromJson(Map<String, dynamic> json) {
    return SyncEventSessionNextCompactionDeltaSyncEvent(
      type: json["type"] as String,
      id: json["id"] as String,
      seq: (json["seq"] as num).toDouble(),
      aggregateID: json["aggregateID"] as String,
      data: SyncEventSessionNextCompactionDeltaSyncEventData.fromJson(json["data"] as Map<String, dynamic>),
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
      (other is SyncEventSessionNextCompactionDeltaSyncEvent &&
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
  final SyncEventSessionNextCompactionDeltaSyncEventData data;
}

@immutable
class SyncEventSessionNextCompactionDeltaSyncEventData {
  const SyncEventSessionNextCompactionDeltaSyncEventData({
    required this.timestamp,
    required this.sessionID,
    required this.text,
  });

  factory SyncEventSessionNextCompactionDeltaSyncEventData.fromJson(Map<String, dynamic> json) {
    return SyncEventSessionNextCompactionDeltaSyncEventData(
      timestamp: (json["timestamp"] as num).toDouble(),
      sessionID: json["sessionID"] as String,
      text: json["text"] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "timestamp": timestamp,
      "sessionID": sessionID,
      "text": text,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncEventSessionNextCompactionDeltaSyncEventData &&
          other.timestamp == timestamp &&
          other.sessionID == sessionID &&
          other.text == text);

  @override
  int get hashCode => Object.hash(timestamp, sessionID, text);

  final double timestamp;
  final String sessionID;
  final String text;
}
