// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)

import 'package:meta/meta.dart';
import 'event.dart';
import 'session.dart';

@immutable
class EventSessionUpdated implements Event {
  const EventSessionUpdated({
    required this.id,
    required this.properties,
  });

  factory EventSessionUpdated.fromJson(Map<String, dynamic> json) {
    return EventSessionUpdated(
      id: json["id"] as String,
      properties: EventSessionUpdatedProperties.fromJson(json["properties"] as Map<String, dynamic>),
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "type": "session.updated",
      "properties": properties.toJson(),
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EventSessionUpdated &&
          other.id == id &&
          other.properties == properties);

  @override
  int get hashCode => Object.hash(id, properties);

  final String id;
  final EventSessionUpdatedProperties properties;
}

@immutable
class EventSessionUpdatedProperties {
  const EventSessionUpdatedProperties({
    required this.sessionID,
    required this.info,
  });

  factory EventSessionUpdatedProperties.fromJson(Map<String, dynamic> json) {
    return EventSessionUpdatedProperties(
      sessionID: json["sessionID"] as String,
      info: Session.fromJson(json["info"] as Map<String, dynamic>),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "sessionID": sessionID,
      "info": info.toJson(),
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EventSessionUpdatedProperties &&
          other.sessionID == sessionID &&
          other.info == info);

  @override
  int get hashCode => Object.hash(sessionID, info);

  final String sessionID;
  final Session info;
}
