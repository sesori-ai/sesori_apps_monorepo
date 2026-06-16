// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.17.3 (8c8011336163d7e7fb24a6a4a049cdb1f6e6ee74)

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';
import 'event.g.dart';

@immutable
class EventSessionError implements Event {
  const EventSessionError({
    required this.id,
    required this.properties,
  });

  factory EventSessionError.fromJson(Map<String, dynamic> json) {
    return EventSessionError(
      id: json["id"] as String,
      properties: EventSessionErrorProperties.fromJson(json["properties"] as Map<String, dynamic>),
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "type": "session.error",
      "properties": properties.toJson(),
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  EventSessionError copyWith({
    String? id,
    EventSessionErrorProperties? properties,
  }) {
    return EventSessionError(
      id: id ?? this.id,
      properties: properties ?? this.properties,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EventSessionError &&
          other.id == id &&
          other.properties == properties);

  @override
  int get hashCode => Object.hash(id, properties);

  final String id;
  final EventSessionErrorProperties properties;
}

@immutable
class EventSessionErrorProperties {
  const EventSessionErrorProperties({
    required this.sessionID,
    required this.error,
  });

  factory EventSessionErrorProperties.fromJson(Map<String, dynamic> json) {
    return EventSessionErrorProperties(
      sessionID: json["sessionID"] as String?,
      error: json["error"] as Object?,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "sessionID": ?sessionID,
      "error": ?error,
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  EventSessionErrorProperties copyWith({
    String? sessionID,
    Object? error,
  }) {
    return EventSessionErrorProperties(
      sessionID: sessionID ?? this.sessionID,
      error: error ?? this.error,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EventSessionErrorProperties &&
          other.sessionID == sessionID &&
          const DeepCollectionEquality().equals(other.error, error));

  @override
  int get hashCode => Object.hash(sessionID, const DeepCollectionEquality().hash(error));

  final String? sessionID;
  final Object? error;
}
