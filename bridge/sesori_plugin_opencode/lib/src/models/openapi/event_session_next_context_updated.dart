// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)

import 'package:meta/meta.dart';
import 'event.dart';

@immutable
class EventSessionNextContextUpdated implements Event {
  const EventSessionNextContextUpdated({
    required this.id,
    required this.properties,
  });

  factory EventSessionNextContextUpdated.fromJson(Map<String, dynamic> json) {
    return EventSessionNextContextUpdated(
      id: json["id"] as String,
      properties: EventSessionNextContextUpdatedProperties.fromJson(json["properties"] as Map<String, dynamic>),
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "type": "session.next.context.updated",
      "properties": properties.toJson(),
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EventSessionNextContextUpdated &&
          other.id == id &&
          other.properties == properties);

  @override
  int get hashCode => Object.hash(id, properties);

  final String id;
  final EventSessionNextContextUpdatedProperties properties;
}

@immutable
class EventSessionNextContextUpdatedProperties {
  const EventSessionNextContextUpdatedProperties({
    required this.timestamp,
    required this.sessionID,
    required this.messageID,
    required this.text,
  });

  factory EventSessionNextContextUpdatedProperties.fromJson(Map<String, dynamic> json) {
    return EventSessionNextContextUpdatedProperties(
      timestamp: (json["timestamp"] as num).toDouble(),
      sessionID: json["sessionID"] as String,
      messageID: json["messageID"] as String,
      text: json["text"] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "timestamp": timestamp,
      "sessionID": sessionID,
      "messageID": messageID,
      "text": text,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EventSessionNextContextUpdatedProperties &&
          other.timestamp == timestamp &&
          other.sessionID == sessionID &&
          other.messageID == messageID &&
          other.text == text);

  @override
  int get hashCode => Object.hash(timestamp, sessionID, messageID, text);

  final double timestamp;
  final String sessionID;
  final String messageID;
  final String text;
}
