// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)

import 'package:meta/meta.dart';
import 'event.dart';
import 'session_error_unknown.dart';

@immutable
class EventSessionNextStepFailed implements Event {
  const EventSessionNextStepFailed({
    required this.id,
    required this.properties,
  });

  factory EventSessionNextStepFailed.fromJson(Map<String, dynamic> json) {
    return EventSessionNextStepFailed(
      id: json["id"] as String,
      properties: EventSessionNextStepFailedProperties.fromJson(json["properties"] as Map<String, dynamic>),
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "type": "session.next.step.failed",
      "properties": properties.toJson(),
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EventSessionNextStepFailed &&
          other.id == id &&
          other.properties == properties);

  @override
  int get hashCode => Object.hash(id, properties);

  final String id;
  final EventSessionNextStepFailedProperties properties;
}

@immutable
class EventSessionNextStepFailedProperties {
  const EventSessionNextStepFailedProperties({
    required this.timestamp,
    required this.sessionID,
    required this.assistantMessageID,
    required this.error,
  });

  factory EventSessionNextStepFailedProperties.fromJson(Map<String, dynamic> json) {
    return EventSessionNextStepFailedProperties(
      timestamp: (json["timestamp"] as num).toDouble(),
      sessionID: json["sessionID"] as String,
      assistantMessageID: json["assistantMessageID"] as String,
      error: SessionErrorUnknown.fromJson(json["error"] as Map<String, dynamic>),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "timestamp": timestamp,
      "sessionID": sessionID,
      "assistantMessageID": assistantMessageID,
      "error": error.toJson(),
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EventSessionNextStepFailedProperties &&
          other.timestamp == timestamp &&
          other.sessionID == sessionID &&
          other.assistantMessageID == assistantMessageID &&
          other.error == error);

  @override
  int get hashCode => Object.hash(timestamp, sessionID, assistantMessageID, error);

  final double timestamp;
  final String sessionID;
  final String assistantMessageID;
  final SessionErrorUnknown error;
}
