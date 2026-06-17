// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.17.7 (4ed4f749e644ffb5b279fb30b7b915e743d80142)

import 'package:meta/meta.dart';
import 'event.g.dart';

@immutable
class EventSessionCompacted implements Event {
  const EventSessionCompacted({
    required this.id,
    required this.properties,
  });

  factory EventSessionCompacted.fromJson(Map<String, dynamic> json) {
    return EventSessionCompacted(
      id: json["id"] as String,
      properties: EventSessionCompactedProperties.fromJson(json["properties"] as Map<String, dynamic>),
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "type": "session.compacted",
      "properties": properties.toJson(),
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  EventSessionCompacted copyWith({
    String? id,
    EventSessionCompactedProperties? properties,
  }) {
    return EventSessionCompacted(
      id: id ?? this.id,
      properties: properties ?? this.properties,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EventSessionCompacted &&
          other.id == id &&
          other.properties == properties);

  @override
  int get hashCode => Object.hash(id, properties);

  final String id;
  final EventSessionCompactedProperties properties;
}

@immutable
class EventSessionCompactedProperties {
  const EventSessionCompactedProperties({
    required this.sessionID,
  });

  factory EventSessionCompactedProperties.fromJson(Map<String, dynamic> json) {
    return EventSessionCompactedProperties(
      sessionID: json["sessionID"] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "sessionID": sessionID,
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  EventSessionCompactedProperties copyWith({
    String? sessionID,
  }) {
    return EventSessionCompactedProperties(
      sessionID: sessionID ?? this.sessionID,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EventSessionCompactedProperties &&
          other.sessionID == sessionID);

  @override
  int get hashCode => sessionID.hashCode;

  final String sessionID;
}
