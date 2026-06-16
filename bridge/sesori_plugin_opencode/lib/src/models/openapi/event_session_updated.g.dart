// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.17.3 (8c8011336163d7e7fb24a6a4a049cdb1f6e6ee74)

import 'package:meta/meta.dart';
import 'event.g.dart';
import 'session.g.dart';

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

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  EventSessionUpdated copyWith({
    String? id,
    EventSessionUpdatedProperties? properties,
  }) {
    return EventSessionUpdated(
      id: id ?? this.id,
      properties: properties ?? this.properties,
    );
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

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  EventSessionUpdatedProperties copyWith({
    String? sessionID,
    Session? info,
  }) {
    return EventSessionUpdatedProperties(
      sessionID: sessionID ?? this.sessionID,
      info: info ?? this.info,
    );
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
