// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)

import 'package:meta/meta.dart';
import 'location_ref.dart';

@immutable
class SyncEventSessionNextMoved {
  const SyncEventSessionNextMoved({
    required this.type,
    required this.id,
    required this.syncEvent,
  });

  factory SyncEventSessionNextMoved.fromJson(Map<String, dynamic> json) {
    return SyncEventSessionNextMoved(
      type: json["type"] as String,
      id: json["id"] as String,
      syncEvent: SyncEventSessionNextMovedSyncEvent.fromJson(json["syncEvent"] as Map<String, dynamic>),
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
      (other is SyncEventSessionNextMoved &&
          other.type == type &&
          other.id == id &&
          other.syncEvent == syncEvent);

  @override
  int get hashCode => Object.hash(type, id, syncEvent);

  final String type;
  final String id;
  final SyncEventSessionNextMovedSyncEvent syncEvent;
}

@immutable
class SyncEventSessionNextMovedSyncEvent {
  const SyncEventSessionNextMovedSyncEvent({
    required this.type,
    required this.id,
    required this.seq,
    required this.aggregateID,
    required this.data,
  });

  factory SyncEventSessionNextMovedSyncEvent.fromJson(Map<String, dynamic> json) {
    return SyncEventSessionNextMovedSyncEvent(
      type: json["type"] as String,
      id: json["id"] as String,
      seq: (json["seq"] as num).toDouble(),
      aggregateID: json["aggregateID"] as String,
      data: SyncEventSessionNextMovedSyncEventData.fromJson(json["data"] as Map<String, dynamic>),
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
      (other is SyncEventSessionNextMovedSyncEvent &&
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
  final SyncEventSessionNextMovedSyncEventData data;
}

@immutable
class SyncEventSessionNextMovedSyncEventData {
  const SyncEventSessionNextMovedSyncEventData({
    required this.timestamp,
    required this.sessionID,
    required this.location,
    this.subdirectory,
  });

  factory SyncEventSessionNextMovedSyncEventData.fromJson(Map<String, dynamic> json) {
    return SyncEventSessionNextMovedSyncEventData(
      timestamp: (json["timestamp"] as num).toDouble(),
      sessionID: json["sessionID"] as String,
      location: LocationRef.fromJson(json["location"] as Map<String, dynamic>),
      subdirectory: json["subdirectory"] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "timestamp": timestamp,
      "sessionID": sessionID,
      "location": location.toJson(),
      "subdirectory": ?subdirectory,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncEventSessionNextMovedSyncEventData &&
          other.timestamp == timestamp &&
          other.sessionID == sessionID &&
          other.location == location &&
          other.subdirectory == subdirectory);

  @override
  int get hashCode => Object.hash(timestamp, sessionID, location, subdirectory);

  final double timestamp;
  final String sessionID;
  final LocationRef location;
  final String? subdirectory;
}
