// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)

import 'package:meta/meta.dart';
import 'event.dart';

@immutable
class EventSessionIdle implements Event {
  const EventSessionIdle({
    required this.id,
    required this.properties,
  });

  factory EventSessionIdle.fromJson(Map<String, dynamic> json) {
    return EventSessionIdle(
      id: json["id"] as String,
      properties: EventSessionIdleProperties.fromJson(json["properties"] as Map<String, dynamic>),
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "type": "session.idle",
      "properties": properties.toJson(),
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EventSessionIdle &&
          other.id == id &&
          other.properties == properties);

  @override
  int get hashCode => Object.hash(id, properties);

  final String id;
  final EventSessionIdleProperties properties;
}

@immutable
class EventSessionIdleProperties {
  const EventSessionIdleProperties({
    required this.sessionID,
  });

  factory EventSessionIdleProperties.fromJson(Map<String, dynamic> json) {
    return EventSessionIdleProperties(
      sessionID: json["sessionID"] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "sessionID": sessionID,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EventSessionIdleProperties &&
          other.sessionID == sessionID);

  @override
  int get hashCode => sessionID.hashCode;

  final String sessionID;
}
