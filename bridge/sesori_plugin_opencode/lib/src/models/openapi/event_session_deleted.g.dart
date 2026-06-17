// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.17.7 (4ed4f749e644ffb5b279fb30b7b915e743d80142)

import 'package:meta/meta.dart';
import 'event.g.dart';
import 'session.g.dart';

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

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  EventSessionDeleted copyWith({
    String? id,
    EventSessionDeletedProperties? properties,
  }) {
    return EventSessionDeleted(
      id: id ?? this.id,
      properties: properties ?? this.properties,
    );
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

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  EventSessionDeletedProperties copyWith({
    String? sessionID,
    Session? info,
  }) {
    return EventSessionDeletedProperties(
      sessionID: sessionID ?? this.sessionID,
      info: info ?? this.info,
    );
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
