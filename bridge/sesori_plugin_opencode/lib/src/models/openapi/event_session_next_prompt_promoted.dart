// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)

import 'package:meta/meta.dart';
import 'event.dart';
import 'prompt.dart';

@immutable
class EventSessionNextPromptPromoted implements Event {
  const EventSessionNextPromptPromoted({
    required this.id,
    required this.properties,
  });

  factory EventSessionNextPromptPromoted.fromJson(Map<String, dynamic> json) {
    return EventSessionNextPromptPromoted(
      id: json["id"] as String,
      properties: EventSessionNextPromptPromotedProperties.fromJson(json["properties"] as Map<String, dynamic>),
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "type": "session.next.prompt.promoted",
      "properties": properties.toJson(),
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EventSessionNextPromptPromoted &&
          other.id == id &&
          other.properties == properties);

  @override
  int get hashCode => Object.hash(id, properties);

  final String id;
  final EventSessionNextPromptPromotedProperties properties;
}

@immutable
class EventSessionNextPromptPromotedProperties {
  const EventSessionNextPromptPromotedProperties({
    required this.timestamp,
    required this.sessionID,
    required this.messageID,
    required this.prompt,
    required this.timeCreated,
  });

  factory EventSessionNextPromptPromotedProperties.fromJson(Map<String, dynamic> json) {
    return EventSessionNextPromptPromotedProperties(
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
      (other is EventSessionNextPromptPromotedProperties &&
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
