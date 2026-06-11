// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)

import 'package:meta/meta.dart';
import 'event.dart';
import 'location_ref.dart';

@immutable
class EventSessionNextMoved implements Event {
  const EventSessionNextMoved({
    required this.id,
    required this.properties,
  });

  factory EventSessionNextMoved.fromJson(Map<String, dynamic> json) {
    return EventSessionNextMoved(
      id: json["id"] as String,
      properties: EventSessionNextMovedProperties.fromJson(json["properties"] as Map<String, dynamic>),
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "type": "session.next.moved",
      "properties": properties.toJson(),
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EventSessionNextMoved &&
          other.id == id &&
          other.properties == properties);

  @override
  int get hashCode => Object.hash(id, properties);

  final String id;
  final EventSessionNextMovedProperties properties;
}

@immutable
class EventSessionNextMovedProperties {
  const EventSessionNextMovedProperties({
    required this.timestamp,
    required this.sessionID,
    required this.location,
    this.subdirectory,
  });

  factory EventSessionNextMovedProperties.fromJson(Map<String, dynamic> json) {
    return EventSessionNextMovedProperties(
      timestamp: (json["timestamp"] as num).toDouble(),
      sessionID: json["sessionID"] as String,
      location: LocationRef.fromJson(json["location"] as Map<String, dynamic>),
      subdirectory: json["subdirectory"] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "timestamp": timestamp,
      "sessionID": sessionID,
      "location": location.toJson(),
      "subdirectory": ?subdirectory,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EventSessionNextMovedProperties &&
          other.timestamp == timestamp &&
          other.sessionID == sessionID &&
          other.location == location &&
          other.subdirectory == subdirectory);

  @override
  int get hashCode => Object.hash(timestamp, sessionID, location, subdirectory);

  final double timestamp;
  final String sessionID;
  final LocationRef location;
  final String? subdirectory;
}
