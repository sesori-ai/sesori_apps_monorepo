// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.17.3 (8c8011336163d7e7fb24a6a4a049cdb1f6e6ee74)

import 'package:meta/meta.dart';
import 'event.g.dart';
import 'session_status.g.dart';

@immutable
class EventSessionStatus implements Event {
  const EventSessionStatus({
    this.id = '',
    required this.properties,
  });

  factory EventSessionStatus.fromJson(Map<String, dynamic> json) {
    return EventSessionStatus(
      id: (json["id"] ?? '') as String,
      properties: EventSessionStatusProperties.fromJson((json["properties"] ?? const <String, dynamic>{}) as Map<String, dynamic>),
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "type": "session.status",
      "properties": properties.toJson(),
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  EventSessionStatus copyWith({
    String? id,
    EventSessionStatusProperties? properties,
  }) {
    return EventSessionStatus(
      id: id ?? this.id,
      properties: properties ?? this.properties,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EventSessionStatus &&
          other.id == id &&
          other.properties == properties);

  @override
  int get hashCode => Object.hash(id, properties);

  final String id;
  final EventSessionStatusProperties properties;
}

@immutable
class EventSessionStatusProperties {
  const EventSessionStatusProperties({
    this.sessionID = '',
    required this.status,
  });

  factory EventSessionStatusProperties.fromJson(Map<String, dynamic> json) {
    return EventSessionStatusProperties(
      sessionID: (json["sessionID"] ?? '') as String,
      status: SessionStatus.fromJson((json["status"] ?? const <String, dynamic>{}) as Object),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "sessionID": sessionID,
      "status": status.toJson(),
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  EventSessionStatusProperties copyWith({
    String? sessionID,
    SessionStatus? status,
  }) {
    return EventSessionStatusProperties(
      sessionID: sessionID ?? this.sessionID,
      status: status ?? this.status,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EventSessionStatusProperties &&
          other.sessionID == sessionID &&
          other.status == status);

  @override
  int get hashCode => Object.hash(sessionID, status);

  final String sessionID;
  final SessionStatus status;
}
