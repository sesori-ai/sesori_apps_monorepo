// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.17.7 (4ed4f749e644ffb5b279fb30b7b915e743d80142)

import 'package:meta/meta.dart';
import 'event.g.dart';
import 'part.g.dart';

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

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  EventMessagePartUpdated copyWith({
    String? id,
    EventMessagePartUpdatedProperties? properties,
  }) {
    return EventMessagePartUpdated(
      id: id ?? this.id,
      properties: properties ?? this.properties,
    );
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

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  EventMessagePartUpdatedProperties copyWith({
    String? sessionID,
    Part? part,
    double? time,
  }) {
    return EventMessagePartUpdatedProperties(
      sessionID: sessionID ?? this.sessionID,
      part: part ?? this.part,
      time: time ?? this.time,
    );
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
