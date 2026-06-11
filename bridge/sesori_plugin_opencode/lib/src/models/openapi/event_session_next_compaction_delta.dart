// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)

import 'package:meta/meta.dart';
import 'event.dart';

@immutable
class EventSessionNextCompactionDelta implements Event {
  const EventSessionNextCompactionDelta({
    required this.id,
    required this.properties,
  });

  factory EventSessionNextCompactionDelta.fromJson(Map<String, dynamic> json) {
    return EventSessionNextCompactionDelta(
      id: json["id"] as String,
      properties: EventSessionNextCompactionDeltaProperties.fromJson(json["properties"] as Map<String, dynamic>),
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "type": "session.next.compaction.delta",
      "properties": properties.toJson(),
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EventSessionNextCompactionDelta &&
          other.id == id &&
          other.properties == properties);

  @override
  int get hashCode => Object.hash(id, properties);

  final String id;
  final EventSessionNextCompactionDeltaProperties properties;
}

@immutable
class EventSessionNextCompactionDeltaProperties {
  const EventSessionNextCompactionDeltaProperties({
    required this.timestamp,
    required this.sessionID,
    required this.text,
  });

  factory EventSessionNextCompactionDeltaProperties.fromJson(Map<String, dynamic> json) {
    return EventSessionNextCompactionDeltaProperties(
      timestamp: (json["timestamp"] as num).toDouble(),
      sessionID: json["sessionID"] as String,
      text: json["text"] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "timestamp": timestamp,
      "sessionID": sessionID,
      "text": text,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EventSessionNextCompactionDeltaProperties &&
          other.timestamp == timestamp &&
          other.sessionID == sessionID &&
          other.text == text);

  @override
  int get hashCode => Object.hash(timestamp, sessionID, text);

  final double timestamp;
  final String sessionID;
  final String text;
}
