// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)

import 'package:meta/meta.dart';
import 'event.dart';
import 'part.dart';

@immutable
class EventMessagePartUpdated implements Event {
  const EventMessagePartUpdated({
    required this.id,
    required this.properties,
  });

  factory EventMessagePartUpdated.fromJson(Map<String, dynamic> json) {
    return EventMessagePartUpdated(
      id: json["id"] as String,
      properties: EventMessagePartUpdatedProperties.fromJson(json["properties"] as Map<String, dynamic>),
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "type": "message.part.updated",
      "properties": properties.toJson(),
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EventMessagePartUpdated &&
          other.id == id &&
          other.properties == properties);

  @override
  int get hashCode => Object.hash(id, properties);

  final String id;
  final EventMessagePartUpdatedProperties properties;
}

@immutable
class EventMessagePartUpdatedProperties {
  const EventMessagePartUpdatedProperties({
    required this.sessionID,
    required this.part,
    required this.time,
  });

  factory EventMessagePartUpdatedProperties.fromJson(Map<String, dynamic> json) {
    return EventMessagePartUpdatedProperties(
      sessionID: json["sessionID"] as String,
      part: Part.fromJson(json["part"] as Object),
      time: (json["time"] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "sessionID": sessionID,
      "part": part.toJson(),
      "time": time,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EventMessagePartUpdatedProperties &&
          other.sessionID == sessionID &&
          other.part == part &&
          other.time == time);

  @override
  int get hashCode => Object.hash(sessionID, part, time);

  final String sessionID;
  final Part part;
  final double time;
}
