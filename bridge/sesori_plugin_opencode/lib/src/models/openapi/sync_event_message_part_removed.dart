// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)

import 'package:meta/meta.dart';

@immutable
class SyncEventMessagePartRemoved {
  const SyncEventMessagePartRemoved({
    required this.type,
    required this.id,
    required this.syncEvent,
  });

  factory SyncEventMessagePartRemoved.fromJson(Map<String, dynamic> json) {
    return SyncEventMessagePartRemoved(
      type: json["type"] as String,
      id: json["id"] as String,
      syncEvent: SyncEventMessagePartRemovedSyncEvent.fromJson(json["syncEvent"] as Map<String, dynamic>),
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
      (other is SyncEventMessagePartRemoved &&
          other.type == type &&
          other.id == id &&
          other.syncEvent == syncEvent);

  @override
  int get hashCode => Object.hash(type, id, syncEvent);

  final String type;
  final String id;
  final SyncEventMessagePartRemovedSyncEvent syncEvent;
}

@immutable
class SyncEventMessagePartRemovedSyncEvent {
  const SyncEventMessagePartRemovedSyncEvent({
    required this.type,
    required this.id,
    required this.seq,
    required this.aggregateID,
    required this.data,
  });

  factory SyncEventMessagePartRemovedSyncEvent.fromJson(Map<String, dynamic> json) {
    return SyncEventMessagePartRemovedSyncEvent(
      type: json["type"] as String,
      id: json["id"] as String,
      seq: (json["seq"] as num).toDouble(),
      aggregateID: json["aggregateID"] as String,
      data: SyncEventMessagePartRemovedSyncEventData.fromJson(json["data"] as Map<String, dynamic>),
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
      (other is SyncEventMessagePartRemovedSyncEvent &&
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
  final SyncEventMessagePartRemovedSyncEventData data;
}

@immutable
class SyncEventMessagePartRemovedSyncEventData {
  const SyncEventMessagePartRemovedSyncEventData({
    required this.sessionID,
    required this.messageID,
    required this.partID,
  });

  factory SyncEventMessagePartRemovedSyncEventData.fromJson(Map<String, dynamic> json) {
    return SyncEventMessagePartRemovedSyncEventData(
      sessionID: json["sessionID"] as String,
      messageID: json["messageID"] as String,
      partID: json["partID"] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "sessionID": sessionID,
      "messageID": messageID,
      "partID": partID,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncEventMessagePartRemovedSyncEventData &&
          other.sessionID == sessionID &&
          other.messageID == messageID &&
          other.partID == partID);

  @override
  int get hashCode => Object.hash(sessionID, messageID, partID);

  final String sessionID;
  final String messageID;
  final String partID;
}
