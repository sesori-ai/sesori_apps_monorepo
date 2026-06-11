// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.17.3 (8c8011336163d7e7fb24a6a4a049cdb1f6e6ee74)

import 'package:meta/meta.dart';
import 'event.g.dart';

@immutable
class EventWorkspaceFailed implements Event {
  const EventWorkspaceFailed({
    this.id = '',
    required this.properties,
  });

  factory EventWorkspaceFailed.fromJson(Map<String, dynamic> json) {
    return EventWorkspaceFailed(
      id: (json["id"] ?? '') as String,
      properties: EventWorkspaceFailedProperties.fromJson((json["properties"] ?? const <String, dynamic>{}) as Map<String, dynamic>),
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "type": "workspace.failed",
      "properties": properties.toJson(),
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  EventWorkspaceFailed copyWith({
    String? id,
    EventWorkspaceFailedProperties? properties,
  }) {
    return EventWorkspaceFailed(
      id: id ?? this.id,
      properties: properties ?? this.properties,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EventWorkspaceFailed &&
          other.id == id &&
          other.properties == properties);

  @override
  int get hashCode => Object.hash(id, properties);

  final String id;
  final EventWorkspaceFailedProperties properties;
}

@immutable
class EventWorkspaceFailedProperties {
  const EventWorkspaceFailedProperties({
    this.message = '',
  });

  factory EventWorkspaceFailedProperties.fromJson(Map<String, dynamic> json) {
    return EventWorkspaceFailedProperties(
      message: (json["message"] ?? '') as String,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "message": message,
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  EventWorkspaceFailedProperties copyWith({
    String? message,
  }) {
    return EventWorkspaceFailedProperties(
      message: message ?? this.message,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EventWorkspaceFailedProperties &&
          other.message == message);

  @override
  int get hashCode => message.hashCode;

  final String message;
}
