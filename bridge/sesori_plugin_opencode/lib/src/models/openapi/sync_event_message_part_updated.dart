// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)

import 'package:meta/meta.dart';
import 'part.dart';

@immutable
class SyncEventMessagePartUpdated {
  const SyncEventMessagePartUpdated({
    required this.type,
    required this.id,
    required this.syncEvent,
  });

  factory SyncEventMessagePartUpdated.fromJson(Map<String, dynamic> json) {
    return SyncEventMessagePartUpdated(
      type: json["type"] as String,
      id: json["id"] as String,
      syncEvent: SyncEventMessagePartUpdatedSyncEvent.fromJson(json["syncEvent"] as Map<String, dynamic>),
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
      (other is SyncEventMessagePartUpdated &&
          other.type == type &&
          other.id == id &&
          other.syncEvent == syncEvent);

  @override
  int get hashCode => Object.hash(type, id, syncEvent);

  final String type;
  final String id;
  final SyncEventMessagePartUpdatedSyncEvent syncEvent;
}

@immutable
class SyncEventMessagePartUpdatedSyncEvent {
  const SyncEventMessagePartUpdatedSyncEvent({
    required this.type,
    required this.id,
    required this.seq,
    required this.aggregateID,
    required this.data,
  });

  factory SyncEventMessagePartUpdatedSyncEvent.fromJson(Map<String, dynamic> json) {
    return SyncEventMessagePartUpdatedSyncEvent(
      type: json["type"] as String,
      id: json["id"] as String,
      seq: (json["seq"] as num).toDouble(),
      aggregateID: json["aggregateID"] as String,
      data: SyncEventMessagePartUpdatedSyncEventData.fromJson(json["data"] as Map<String, dynamic>),
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
      (other is SyncEventMessagePartUpdatedSyncEvent &&
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
  final SyncEventMessagePartUpdatedSyncEventData data;
}

@immutable
class SyncEventMessagePartUpdatedSyncEventData {
  const SyncEventMessagePartUpdatedSyncEventData({
    required this.sessionID,
    required this.part,
    required this.time,
  });

  factory SyncEventMessagePartUpdatedSyncEventData.fromJson(Map<String, dynamic> json) {
    return SyncEventMessagePartUpdatedSyncEventData(
      sessionID: json["sessionID"] as String,
      part: Part.fromJson(json["part"] as Object),
      time: (json["time"] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "sessionID": sessionID,
      "part": part.toJson(),
      "time": time,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncEventMessagePartUpdatedSyncEventData &&
          other.sessionID == sessionID &&
          other.part == part &&
          other.time == time);

  @override
  int get hashCode => Object.hash(sessionID, part, time);

  final String sessionID;
  final Part part;
  final double time;
}
