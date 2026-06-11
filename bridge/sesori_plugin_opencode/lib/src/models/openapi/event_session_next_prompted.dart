// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)

import 'package:meta/meta.dart';
import 'event.dart';
import 'prompt.dart';

@immutable
class EventSessionNextPrompted implements Event {
  const EventSessionNextPrompted({
    required this.id,
    required this.properties,
  });

  factory EventSessionNextPrompted.fromJson(Map<String, dynamic> json) {
    return EventSessionNextPrompted(
      id: json["id"] as String,
      properties: EventSessionNextPromptedProperties.fromJson(json["properties"] as Map<String, dynamic>),
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "type": "session.next.prompted",
      "properties": properties.toJson(),
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EventSessionNextPrompted &&
          other.id == id &&
          other.properties == properties);

  @override
  int get hashCode => Object.hash(id, properties);

  final String id;
  final EventSessionNextPromptedProperties properties;
}

@immutable
class EventSessionNextPromptedProperties {
  const EventSessionNextPromptedProperties({
    required this.timestamp,
    required this.sessionID,
    required this.messageID,
    required this.prompt,
    required this.delivery,
  });

  factory EventSessionNextPromptedProperties.fromJson(Map<String, dynamic> json) {
    return EventSessionNextPromptedProperties(
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
      (other is EventSessionNextPromptedProperties &&
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
