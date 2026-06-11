// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)

import 'package:meta/meta.dart';

@immutable
class SyncEventMessageRemoved {
  const SyncEventMessageRemoved({
    required this.type,
    required this.id,
    required this.syncEvent,
  });

  factory SyncEventMessageRemoved.fromJson(Map<String, dynamic> json) {
    return SyncEventMessageRemoved(
      type: json["type"] as String,
      id: json["id"] as String,
      syncEvent: SyncEventMessageRemovedSyncEvent.fromJson(json["syncEvent"] as Map<String, dynamic>),
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
      (other is SyncEventMessageRemoved &&
          other.type == type &&
          other.id == id &&
          other.syncEvent == syncEvent);

  @override
  int get hashCode => Object.hash(type, id, syncEvent);

  final String type;
  final String id;
  final SyncEventMessageRemovedSyncEvent syncEvent;
}

@immutable
class SyncEventMessageRemovedSyncEvent {
  const SyncEventMessageRemovedSyncEvent({
    required this.type,
    required this.id,
    required this.seq,
    required this.aggregateID,
    required this.data,
  });

  factory SyncEventMessageRemovedSyncEvent.fromJson(Map<String, dynamic> json) {
    return SyncEventMessageRemovedSyncEvent(
      type: json["type"] as String,
      id: json["id"] as String,
      seq: (json["seq"] as num).toDouble(),
      aggregateID: json["aggregateID"] as String,
      data: SyncEventMessageRemovedSyncEventData.fromJson(json["data"] as Map<String, dynamic>),
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
      (other is SyncEventMessageRemovedSyncEvent &&
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
  final SyncEventMessageRemovedSyncEventData data;
}

@immutable
class SyncEventMessageRemovedSyncEventData {
  const SyncEventMessageRemovedSyncEventData({
    required this.sessionID,
    required this.messageID,
  });

  factory SyncEventMessageRemovedSyncEventData.fromJson(Map<String, dynamic> json) {
    return SyncEventMessageRemovedSyncEventData(
      sessionID: json["sessionID"] as String,
      messageID: json["messageID"] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "sessionID": sessionID,
      "messageID": messageID,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncEventMessageRemovedSyncEventData &&
          other.sessionID == sessionID &&
          other.messageID == messageID);

  @override
  int get hashCode => Object.hash(sessionID, messageID);

  final String sessionID;
  final String messageID;
}
