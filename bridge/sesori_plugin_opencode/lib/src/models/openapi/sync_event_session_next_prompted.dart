// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)

import 'package:meta/meta.dart';
import 'prompt.dart';

@immutable
class SyncEventSessionNextPrompted {
  const SyncEventSessionNextPrompted({
    required this.type,
    required this.id,
    required this.syncEvent,
  });

  factory SyncEventSessionNextPrompted.fromJson(Map<String, dynamic> json) {
    return SyncEventSessionNextPrompted(
      type: json["type"] as String,
      id: json["id"] as String,
      syncEvent: SyncEventSessionNextPromptedSyncEvent.fromJson(json["syncEvent"] as Map<String, dynamic>),
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
      (other is SyncEventSessionNextPrompted &&
          other.type == type &&
          other.id == id &&
          other.syncEvent == syncEvent);

  @override
  int get hashCode => Object.hash(type, id, syncEvent);

  final String type;
  final String id;
  final SyncEventSessionNextPromptedSyncEvent syncEvent;
}

@immutable
class SyncEventSessionNextPromptedSyncEvent {
  const SyncEventSessionNextPromptedSyncEvent({
    required this.type,
    required this.id,
    required this.seq,
    required this.aggregateID,
    required this.data,
  });

  factory SyncEventSessionNextPromptedSyncEvent.fromJson(Map<String, dynamic> json) {
    return SyncEventSessionNextPromptedSyncEvent(
      type: json["type"] as String,
      id: json["id"] as String,
      seq: (json["seq"] as num).toDouble(),
      aggregateID: json["aggregateID"] as String,
      data: SyncEventSessionNextPromptedSyncEventData.fromJson(json["data"] as Map<String, dynamic>),
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
      (other is SyncEventSessionNextPromptedSyncEvent &&
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
  final SyncEventSessionNextPromptedSyncEventData data;
}

@immutable
class SyncEventSessionNextPromptedSyncEventData {
  const SyncEventSessionNextPromptedSyncEventData({
    required this.timestamp,
    required this.sessionID,
    required this.messageID,
    required this.prompt,
    required this.delivery,
  });

  factory SyncEventSessionNextPromptedSyncEventData.fromJson(Map<String, dynamic> json) {
    return SyncEventSessionNextPromptedSyncEventData(
      timestamp: (json["timestamp"] as num).toDouble(),
      sessionID: json["sessionID"] as String,
      messageID: json["messageID"] as String,
      prompt: Prompt.fromJson(json["prompt"] as Map<String, dynamic>),
      delivery: json["delivery"] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "timestamp": timestamp,
      "sessionID": sessionID,
      "messageID": messageID,
      "prompt": prompt.toJson(),
      "delivery": delivery,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncEventSessionNextPromptedSyncEventData &&
          other.timestamp == timestamp &&
          other.sessionID == sessionID &&
          other.messageID == messageID &&
          other.prompt == prompt &&
          other.delivery == delivery);

  @override
  int get hashCode => Object.hash(timestamp, sessionID, messageID, prompt, delivery);

  final double timestamp;
  final String sessionID;
  final String messageID;
  final Prompt prompt;
  final String delivery;
}
