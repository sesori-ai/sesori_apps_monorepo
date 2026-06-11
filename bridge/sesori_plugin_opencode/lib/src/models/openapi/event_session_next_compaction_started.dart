// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)

import 'package:meta/meta.dart';
import 'event.dart';

@immutable
class EventSessionNextCompactionStarted implements Event {
  const EventSessionNextCompactionStarted({
    required this.id,
    required this.properties,
  });

  factory EventSessionNextCompactionStarted.fromJson(Map<String, dynamic> json) {
    return EventSessionNextCompactionStarted(
      id: json["id"] as String,
      properties: EventSessionNextCompactionStartedProperties.fromJson(json["properties"] as Map<String, dynamic>),
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "type": "session.next.compaction.started",
      "properties": properties.toJson(),
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EventSessionNextCompactionStarted &&
          other.id == id &&
          other.properties == properties);

  @override
  int get hashCode => Object.hash(id, properties);

  final String id;
  final EventSessionNextCompactionStartedProperties properties;
}

@immutable
class EventSessionNextCompactionStartedProperties {
  const EventSessionNextCompactionStartedProperties({
    required this.timestamp,
    required this.sessionID,
    required this.messageID,
    required this.reason,
  });

  factory EventSessionNextCompactionStartedProperties.fromJson(Map<String, dynamic> json) {
    return EventSessionNextCompactionStartedProperties(
      timestamp: (json["timestamp"] as num).toDouble(),
      sessionID: json["sessionID"] as String,
      messageID: json["messageID"] as String,
      reason: json["reason"] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "timestamp": timestamp,
      "sessionID": sessionID,
      "messageID": messageID,
      "reason": reason,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EventSessionNextCompactionStartedProperties &&
          other.timestamp == timestamp &&
          other.sessionID == sessionID &&
          other.messageID == messageID &&
          other.reason == reason);

  @override
  int get hashCode => Object.hash(timestamp, sessionID, messageID, reason);

  final double timestamp;
  final String sessionID;
  final String messageID;
  final String reason;
}
