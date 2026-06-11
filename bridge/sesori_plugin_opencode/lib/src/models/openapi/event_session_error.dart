// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';
import 'event.dart';

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
    this.sessionID,
    this.error,
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
