// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)

import 'package:meta/meta.dart';
import 'event.dart';

@immutable
class EventSessionNextTextStarted implements Event {
  const EventSessionNextTextStarted({
    required this.id,
    required this.properties,
  });

  factory EventSessionNextTextStarted.fromJson(Map<String, dynamic> json) {
    return EventSessionNextTextStarted(
      id: json["id"] as String,
      properties: EventSessionNextTextStartedProperties.fromJson(json["properties"] as Map<String, dynamic>),
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "type": "session.next.text.started",
      "properties": properties.toJson(),
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EventSessionNextTextStarted &&
          other.id == id &&
          other.properties == properties);

  @override
  int get hashCode => Object.hash(id, properties);

  final String id;
  final EventSessionNextTextStartedProperties properties;
}

@immutable
class EventSessionNextTextStartedProperties {
  const EventSessionNextTextStartedProperties({
    required this.timestamp,
    required this.sessionID,
    required this.assistantMessageID,
    required this.textID,
  });

  factory EventSessionNextTextStartedProperties.fromJson(Map<String, dynamic> json) {
    return EventSessionNextTextStartedProperties(
      timestamp: (json["timestamp"] as num).toDouble(),
      sessionID: json["sessionID"] as String,
      assistantMessageID: json["assistantMessageID"] as String,
      textID: json["textID"] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "timestamp": timestamp,
      "sessionID": sessionID,
      "assistantMessageID": assistantMessageID,
      "textID": textID,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EventSessionNextTextStartedProperties &&
          other.timestamp == timestamp &&
          other.sessionID == sessionID &&
          other.assistantMessageID == assistantMessageID &&
          other.textID == textID);

  @override
  int get hashCode => Object.hash(timestamp, sessionID, assistantMessageID, textID);

  final double timestamp;
  final String sessionID;
  final String assistantMessageID;
  final String textID;
}
