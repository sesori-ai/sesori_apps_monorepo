// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)

import 'package:meta/meta.dart';
import 'session.dart';

@immutable
class SyncEventSessionDeleted {
  const SyncEventSessionDeleted({
    required this.type,
    required this.id,
    required this.syncEvent,
  });

  factory SyncEventSessionDeleted.fromJson(Map<String, dynamic> json) {
    return SyncEventSessionDeleted(
      type: json["type"] as String,
      id: json["id"] as String,
      syncEvent: SyncEventSessionDeletedSyncEvent.fromJson(json["syncEvent"] as Map<String, dynamic>),
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
      (other is SyncEventSessionDeleted &&
          other.type == type &&
          other.id == id &&
          other.syncEvent == syncEvent);

  @override
  int get hashCode => Object.hash(type, id, syncEvent);

  final String type;
  final String id;
  final SyncEventSessionDeletedSyncEvent syncEvent;
}

@immutable
class SyncEventSessionDeletedSyncEvent {
  const SyncEventSessionDeletedSyncEvent({
    required this.type,
    required this.id,
    required this.seq,
    required this.aggregateID,
    required this.data,
  });

  factory SyncEventSessionDeletedSyncEvent.fromJson(Map<String, dynamic> json) {
    return SyncEventSessionDeletedSyncEvent(
      type: json["type"] as String,
      id: json["id"] as String,
      seq: (json["seq"] as num).toDouble(),
      aggregateID: json["aggregateID"] as String,
      data: SyncEventSessionDeletedSyncEventData.fromJson(json["data"] as Map<String, dynamic>),
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
      (other is SyncEventSessionDeletedSyncEvent &&
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
  final SyncEventSessionDeletedSyncEventData data;
}

@immutable
class SyncEventSessionDeletedSyncEventData {
  const SyncEventSessionDeletedSyncEventData({
    required this.sessionID,
    required this.info,
  });

  factory SyncEventSessionDeletedSyncEventData.fromJson(Map<String, dynamic> json) {
    return SyncEventSessionDeletedSyncEventData(
      sessionID: json["sessionID"] as String,
      info: Session.fromJson(json["info"] as Map<String, dynamic>),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "sessionID": sessionID,
      "info": info.toJson(),
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncEventSessionDeletedSyncEventData &&
          other.sessionID == sessionID &&
          other.info == info);

  @override
  int get hashCode => Object.hash(sessionID, info);

  final String sessionID;
  final Session info;
}
