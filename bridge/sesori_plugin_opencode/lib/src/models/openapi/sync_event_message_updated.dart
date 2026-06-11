// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)

import 'package:meta/meta.dart';
import 'message.dart';

@immutable
class SyncEventMessageUpdated {
  const SyncEventMessageUpdated({
    required this.type,
    required this.id,
    required this.syncEvent,
  });

  factory SyncEventMessageUpdated.fromJson(Map<String, dynamic> json) {
    return SyncEventMessageUpdated(
      type: json["type"] as String,
      id: json["id"] as String,
      syncEvent: SyncEventMessageUpdatedSyncEvent.fromJson(json["syncEvent"] as Map<String, dynamic>),
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
      (other is SyncEventMessageUpdated &&
          other.type == type &&
          other.id == id &&
          other.syncEvent == syncEvent);

  @override
  int get hashCode => Object.hash(type, id, syncEvent);

  final String type;
  final String id;
  final SyncEventMessageUpdatedSyncEvent syncEvent;
}

@immutable
class SyncEventMessageUpdatedSyncEvent {
  const SyncEventMessageUpdatedSyncEvent({
    required this.type,
    required this.id,
    required this.seq,
    required this.aggregateID,
    required this.data,
  });

  factory SyncEventMessageUpdatedSyncEvent.fromJson(Map<String, dynamic> json) {
    return SyncEventMessageUpdatedSyncEvent(
      type: json["type"] as String,
      id: json["id"] as String,
      seq: (json["seq"] as num).toDouble(),
      aggregateID: json["aggregateID"] as String,
      data: SyncEventMessageUpdatedSyncEventData.fromJson(json["data"] as Map<String, dynamic>),
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
      (other is SyncEventMessageUpdatedSyncEvent &&
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
  final SyncEventMessageUpdatedSyncEventData data;
}

@immutable
class SyncEventMessageUpdatedSyncEventData {
  const SyncEventMessageUpdatedSyncEventData({
    required this.sessionID,
    required this.info,
  });

  factory SyncEventMessageUpdatedSyncEventData.fromJson(Map<String, dynamic> json) {
    return SyncEventMessageUpdatedSyncEventData(
      sessionID: json["sessionID"] as String,
      info: Message.fromJson(json["info"] as Object),
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
      (other is SyncEventMessageUpdatedSyncEventData &&
          other.sessionID == sessionID &&
          other.info == info);

  @override
  int get hashCode => Object.hash(sessionID, info);

  final String sessionID;
  final Message info;
}
