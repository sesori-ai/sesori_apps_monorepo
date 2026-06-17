// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.17.7 (4ed4f749e644ffb5b279fb30b7b915e743d80142)

import 'package:meta/meta.dart';
import 'event.g.dart';
import 'session.g.dart';

@immutable
class EventSessionCreated implements Event {
  const EventSessionCreated({
    required this.id,
    required this.properties,
  });

  factory EventSessionCreated.fromJson(Map<String, dynamic> json) {
    return EventSessionCreated(
      id: json["id"] as String,
      properties: EventSessionCreatedProperties.fromJson(json["properties"] as Map<String, dynamic>),
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "type": "session.created",
      "properties": properties.toJson(),
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  EventSessionCreated copyWith({
    String? id,
    EventSessionCreatedProperties? properties,
  }) {
    return EventSessionCreated(
      id: id ?? this.id,
      properties: properties ?? this.properties,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EventSessionCreated &&
          other.id == id &&
          other.properties == properties);

  @override
  int get hashCode => Object.hash(id, properties);

  final String id;
  final EventSessionCreatedProperties properties;
}

@immutable
class EventSessionCreatedProperties {
  const EventSessionCreatedProperties({
    required this.sessionID,
    required this.info,
  });

  factory EventSessionCreatedProperties.fromJson(Map<String, dynamic> json) {
    return EventSessionCreatedProperties(
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
  EventSessionCreatedProperties copyWith({
    String? sessionID,
    Session? info,
  }) {
    return EventSessionCreatedProperties(
      sessionID: sessionID ?? this.sessionID,
      info: info ?? this.info,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EventSessionCreatedProperties &&
          other.sessionID == sessionID &&
          other.info == info);

  @override
  int get hashCode => Object.hash(sessionID, info);

  final String sessionID;
  final Session info;
}
