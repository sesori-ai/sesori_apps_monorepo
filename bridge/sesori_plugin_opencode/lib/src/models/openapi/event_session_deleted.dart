// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)

import 'package:meta/meta.dart';
import 'event.dart';
import 'session.dart';

@immutable
class EventSessionDeleted implements Event {
  const EventSessionDeleted({
    required this.id,
    required this.properties,
  });

  factory EventSessionDeleted.fromJson(Map<String, dynamic> json) {
    return EventSessionDeleted(
      id: json["id"] as String,
      properties: EventSessionDeletedProperties.fromJson(json["properties"] as Map<String, dynamic>),
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "type": "session.deleted",
      "properties": properties.toJson(),
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EventSessionDeleted &&
          other.id == id &&
          other.properties == properties);

  @override
  int get hashCode => Object.hash(id, properties);

  final String id;
  final EventSessionDeletedProperties properties;
}

@immutable
class EventSessionDeletedProperties {
  const EventSessionDeletedProperties({
    required this.sessionID,
    required this.info,
  });

  factory EventSessionDeletedProperties.fromJson(Map<String, dynamic> json) {
    return EventSessionDeletedProperties(
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
      (other is EventSessionDeletedProperties &&
          other.sessionID == sessionID &&
          other.info == info);

  @override
  int get hashCode => Object.hash(sessionID, info);

  final String sessionID;
  final Session info;
}
