// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)

import 'package:meta/meta.dart';
import 'event.dart';

@immutable
class EventSessionNextTextDelta implements Event {
  const EventSessionNextTextDelta({
    required this.id,
    required this.properties,
  });

  factory EventSessionNextTextDelta.fromJson(Map<String, dynamic> json) {
    return EventSessionNextTextDelta(
      id: json["id"] as String,
      properties: EventSessionNextTextDeltaProperties.fromJson(json["properties"] as Map<String, dynamic>),
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "type": "session.next.text.delta",
      "properties": properties.toJson(),
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EventSessionNextTextDelta &&
          other.id == id &&
          other.properties == properties);

  @override
  int get hashCode => Object.hash(id, properties);

  final String id;
  final EventSessionNextTextDeltaProperties properties;
}

@immutable
class EventSessionNextTextDeltaProperties {
  const EventSessionNextTextDeltaProperties({
    required this.timestamp,
    required this.sessionID,
    required this.assistantMessageID,
    required this.textID,
    required this.delta,
  });

  factory EventSessionNextTextDeltaProperties.fromJson(Map<String, dynamic> json) {
    return EventSessionNextTextDeltaProperties(
      timestamp: (json["timestamp"] as num).toDouble(),
      sessionID: json["sessionID"] as String,
      assistantMessageID: json["assistantMessageID"] as String,
      textID: json["textID"] as String,
      delta: json["delta"] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "timestamp": timestamp,
      "sessionID": sessionID,
      "assistantMessageID": assistantMessageID,
      "textID": textID,
      "delta": delta,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EventSessionNextTextDeltaProperties &&
          other.timestamp == timestamp &&
          other.sessionID == sessionID &&
          other.assistantMessageID == assistantMessageID &&
          other.textID == textID &&
          other.delta == delta);

  @override
  int get hashCode => Object.hash(timestamp, sessionID, assistantMessageID, textID, delta);

  final double timestamp;
  final String sessionID;
  final String assistantMessageID;
  final String textID;
  final String delta;
}
