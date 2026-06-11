// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)

import 'package:meta/meta.dart';
import 'prompt.dart';

@immutable
class SyncEventSessionNextPromptPromoted {
  const SyncEventSessionNextPromptPromoted({
    required this.type,
    required this.id,
    required this.syncEvent,
  });

  factory SyncEventSessionNextPromptPromoted.fromJson(Map<String, dynamic> json) {
    return SyncEventSessionNextPromptPromoted(
      type: json["type"] as String,
      id: json["id"] as String,
      syncEvent: SyncEventSessionNextPromptPromotedSyncEvent.fromJson(json["syncEvent"] as Map<String, dynamic>),
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
      (other is SyncEventSessionNextPromptPromoted &&
          other.type == type &&
          other.id == id &&
          other.syncEvent == syncEvent);

  @override
  int get hashCode => Object.hash(type, id, syncEvent);

  final String type;
  final String id;
  final SyncEventSessionNextPromptPromotedSyncEvent syncEvent;
}

@immutable
class SyncEventSessionNextPromptPromotedSyncEvent {
  const SyncEventSessionNextPromptPromotedSyncEvent({
    required this.type,
    required this.id,
    required this.seq,
    required this.aggregateID,
    required this.data,
  });

  factory SyncEventSessionNextPromptPromotedSyncEvent.fromJson(Map<String, dynamic> json) {
    return SyncEventSessionNextPromptPromotedSyncEvent(
      type: json["type"] as String,
      id: json["id"] as String,
      seq: (json["seq"] as num).toDouble(),
      aggregateID: json["aggregateID"] as String,
      data: SyncEventSessionNextPromptPromotedSyncEventData.fromJson(json["data"] as Map<String, dynamic>),
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
      (other is SyncEventSessionNextPromptPromotedSyncEvent &&
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
  final SyncEventSessionNextPromptPromotedSyncEventData data;
}

@immutable
class SyncEventSessionNextPromptPromotedSyncEventData {
  const SyncEventSessionNextPromptPromotedSyncEventData({
    required this.timestamp,
    required this.sessionID,
    required this.messageID,
    required this.prompt,
    required this.timeCreated,
  });

  factory SyncEventSessionNextPromptPromotedSyncEventData.fromJson(Map<String, dynamic> json) {
    return SyncEventSessionNextPromptPromotedSyncEventData(
      timestamp: (json["timestamp"] as num).toDouble(),
      sessionID: json["sessionID"] as String,
      messageID: json["messageID"] as String,
      prompt: Prompt.fromJson(json["prompt"] as Map<String, dynamic>),
      timeCreated: (json["timeCreated"] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "timestamp": timestamp,
      "sessionID": sessionID,
      "messageID": messageID,
      "prompt": prompt.toJson(),
      "timeCreated": timeCreated,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncEventSessionNextPromptPromotedSyncEventData &&
          other.timestamp == timestamp &&
          other.sessionID == sessionID &&
          other.messageID == messageID &&
          other.prompt == prompt &&
          other.timeCreated == timeCreated);

  @override
  int get hashCode => Object.hash(timestamp, sessionID, messageID, prompt, timeCreated);

  final double timestamp;
  final String sessionID;
  final String messageID;
  final Prompt prompt;
  final double timeCreated;
}
