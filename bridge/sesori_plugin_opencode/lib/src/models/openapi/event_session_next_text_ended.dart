// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)

import 'package:meta/meta.dart';
import 'event.dart';

@immutable
class EventSessionNextTextEnded implements Event {
  const EventSessionNextTextEnded({
    required this.id,
    required this.properties,
  });

  factory EventSessionNextTextEnded.fromJson(Map<String, dynamic> json) {
    return EventSessionNextTextEnded(
      id: json["id"] as String,
      properties: EventSessionNextTextEndedProperties.fromJson(json["properties"] as Map<String, dynamic>),
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "type": "session.next.text.ended",
      "properties": properties.toJson(),
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EventSessionNextTextEnded &&
          other.id == id &&
          other.properties == properties);

  @override
  int get hashCode => Object.hash(id, properties);

  final String id;
  final EventSessionNextTextEndedProperties properties;
}

@immutable
class EventSessionNextTextEndedProperties {
  const EventSessionNextTextEndedProperties({
    required this.timestamp,
    required this.sessionID,
    required this.assistantMessageID,
    required this.textID,
    required this.text,
  });

  factory EventSessionNextTextEndedProperties.fromJson(Map<String, dynamic> json) {
    return EventSessionNextTextEndedProperties(
      timestamp: (json["timestamp"] as num).toDouble(),
      sessionID: json["sessionID"] as String,
      assistantMessageID: json["assistantMessageID"] as String,
      textID: json["textID"] as String,
      text: json["text"] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "timestamp": timestamp,
      "sessionID": sessionID,
      "assistantMessageID": assistantMessageID,
      "textID": textID,
      "text": text,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EventSessionNextTextEndedProperties &&
          other.timestamp == timestamp &&
          other.sessionID == sessionID &&
          other.assistantMessageID == assistantMessageID &&
          other.textID == textID &&
          other.text == text);

  @override
  int get hashCode => Object.hash(timestamp, sessionID, assistantMessageID, textID, text);

  final double timestamp;
  final String sessionID;
  final String assistantMessageID;
  final String textID;
  final String text;
}
