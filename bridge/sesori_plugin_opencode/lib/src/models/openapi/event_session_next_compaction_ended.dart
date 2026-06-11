// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)

import 'package:meta/meta.dart';
import 'event.dart';

@immutable
class EventSessionNextCompactionEnded implements Event {
  const EventSessionNextCompactionEnded({
    required this.id,
    required this.properties,
  });

  factory EventSessionNextCompactionEnded.fromJson(Map<String, dynamic> json) {
    return EventSessionNextCompactionEnded(
      id: json["id"] as String,
      properties: EventSessionNextCompactionEndedProperties.fromJson(json["properties"] as Map<String, dynamic>),
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "type": "session.next.compaction.ended",
      "properties": properties.toJson(),
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EventSessionNextCompactionEnded &&
          other.id == id &&
          other.properties == properties);

  @override
  int get hashCode => Object.hash(id, properties);

  final String id;
  final EventSessionNextCompactionEndedProperties properties;
}

@immutable
class EventSessionNextCompactionEndedProperties {
  const EventSessionNextCompactionEndedProperties({
    required this.timestamp,
    required this.sessionID,
    required this.text,
    this.include,
  });

  factory EventSessionNextCompactionEndedProperties.fromJson(Map<String, dynamic> json) {
    return EventSessionNextCompactionEndedProperties(
      timestamp: (json["timestamp"] as num).toDouble(),
      sessionID: json["sessionID"] as String,
      text: json["text"] as String,
      include: json["include"] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "timestamp": timestamp,
      "sessionID": sessionID,
      "text": text,
      "include": ?include,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EventSessionNextCompactionEndedProperties &&
          other.timestamp == timestamp &&
          other.sessionID == sessionID &&
          other.text == text &&
          other.include == include);

  @override
  int get hashCode => Object.hash(timestamp, sessionID, text, include);

  final double timestamp;
  final String sessionID;
  final String text;
  final String? include;
}
