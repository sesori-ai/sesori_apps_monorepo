// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)

import 'package:meta/meta.dart';
import 'event.dart';

@immutable
class EventSessionNextToolInputEnded implements Event {
  const EventSessionNextToolInputEnded({
    required this.id,
    required this.properties,
  });

  factory EventSessionNextToolInputEnded.fromJson(Map<String, dynamic> json) {
    return EventSessionNextToolInputEnded(
      id: json["id"] as String,
      properties: EventSessionNextToolInputEndedProperties.fromJson(json["properties"] as Map<String, dynamic>),
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "type": "session.next.tool.input.ended",
      "properties": properties.toJson(),
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EventSessionNextToolInputEnded &&
          other.id == id &&
          other.properties == properties);

  @override
  int get hashCode => Object.hash(id, properties);

  final String id;
  final EventSessionNextToolInputEndedProperties properties;
}

@immutable
class EventSessionNextToolInputEndedProperties {
  const EventSessionNextToolInputEndedProperties({
    required this.timestamp,
    required this.sessionID,
    required this.assistantMessageID,
    required this.callID,
    required this.text,
  });

  factory EventSessionNextToolInputEndedProperties.fromJson(Map<String, dynamic> json) {
    return EventSessionNextToolInputEndedProperties(
      timestamp: (json["timestamp"] as num).toDouble(),
      sessionID: json["sessionID"] as String,
      assistantMessageID: json["assistantMessageID"] as String,
      callID: json["callID"] as String,
      text: json["text"] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "timestamp": timestamp,
      "sessionID": sessionID,
      "assistantMessageID": assistantMessageID,
      "callID": callID,
      "text": text,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EventSessionNextToolInputEndedProperties &&
          other.timestamp == timestamp &&
          other.sessionID == sessionID &&
          other.assistantMessageID == assistantMessageID &&
          other.callID == callID &&
          other.text == text);

  @override
  int get hashCode => Object.hash(timestamp, sessionID, assistantMessageID, callID, text);

  final double timestamp;
  final String sessionID;
  final String assistantMessageID;
  final String callID;
  final String text;
}
