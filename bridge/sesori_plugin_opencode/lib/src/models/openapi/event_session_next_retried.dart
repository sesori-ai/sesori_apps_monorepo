// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)

import 'package:meta/meta.dart';
import 'event.dart';
import 'session_next_retry_error.dart';

@immutable
class EventSessionNextRetried implements Event {
  const EventSessionNextRetried({
    required this.id,
    required this.properties,
  });

  factory EventSessionNextRetried.fromJson(Map<String, dynamic> json) {
    return EventSessionNextRetried(
      id: json["id"] as String,
      properties: EventSessionNextRetriedProperties.fromJson(json["properties"] as Map<String, dynamic>),
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "type": "session.next.retried",
      "properties": properties.toJson(),
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EventSessionNextRetried &&
          other.id == id &&
          other.properties == properties);

  @override
  int get hashCode => Object.hash(id, properties);

  final String id;
  final EventSessionNextRetriedProperties properties;
}

@immutable
class EventSessionNextRetriedProperties {
  const EventSessionNextRetriedProperties({
    required this.timestamp,
    required this.sessionID,
    required this.attempt,
    required this.error,
  });

  factory EventSessionNextRetriedProperties.fromJson(Map<String, dynamic> json) {
    return EventSessionNextRetriedProperties(
      timestamp: (json["timestamp"] as num).toDouble(),
      sessionID: json["sessionID"] as String,
      attempt: (json["attempt"] as num).toDouble(),
      error: SessionNextRetryError.fromJson(json["error"] as Map<String, dynamic>),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "timestamp": timestamp,
      "sessionID": sessionID,
      "attempt": attempt,
      "error": error.toJson(),
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EventSessionNextRetriedProperties &&
          other.timestamp == timestamp &&
          other.sessionID == sessionID &&
          other.attempt == attempt &&
          other.error == error);

  @override
  int get hashCode => Object.hash(timestamp, sessionID, attempt, error);

  final double timestamp;
  final String sessionID;
  final double attempt;
  final SessionNextRetryError error;
}
