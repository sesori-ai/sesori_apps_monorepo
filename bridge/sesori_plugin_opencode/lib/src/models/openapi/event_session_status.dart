// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)

import 'package:meta/meta.dart';
import 'event.dart';
import 'session_status.dart';

@immutable
class EventSessionStatus implements Event {
  const EventSessionStatus({
    required this.id,
    required this.properties,
  });

  factory EventSessionStatus.fromJson(Map<String, dynamic> json) {
    return EventSessionStatus(
      id: json["id"] as String,
      properties: EventSessionStatusProperties.fromJson(json["properties"] as Map<String, dynamic>),
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "type": "session.status",
      "properties": properties.toJson(),
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EventSessionStatus &&
          other.id == id &&
          other.properties == properties);

  @override
  int get hashCode => Object.hash(id, properties);

  final String id;
  final EventSessionStatusProperties properties;
}

@immutable
class EventSessionStatusProperties {
  const EventSessionStatusProperties({
    required this.sessionID,
    required this.status,
  });

  factory EventSessionStatusProperties.fromJson(Map<String, dynamic> json) {
    return EventSessionStatusProperties(
      sessionID: json["sessionID"] as String,
      status: SessionStatus.fromJson(json["status"] as Object),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "sessionID": sessionID,
      "status": status.toJson(),
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EventSessionStatusProperties &&
          other.sessionID == sessionID &&
          other.status == status);

  @override
  int get hashCode => Object.hash(sessionID, status);

  final String sessionID;
  final SessionStatus status;
}
