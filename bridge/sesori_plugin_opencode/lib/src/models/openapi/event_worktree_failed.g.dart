// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.17.3 (8c8011336163d7e7fb24a6a4a049cdb1f6e6ee74)

import 'package:meta/meta.dart';
import 'event.g.dart';

@immutable
class EventWorktreeFailed implements Event {
  const EventWorktreeFailed({
    this.id = '',
    required this.properties,
  });

  factory EventWorktreeFailed.fromJson(Map<String, dynamic> json) {
    return EventWorktreeFailed(
      id: (json["id"] ?? '') as String,
      properties: EventWorktreeFailedProperties.fromJson((json["properties"] ?? const <String, dynamic>{}) as Map<String, dynamic>),
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "type": "worktree.failed",
      "properties": properties.toJson(),
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  EventWorktreeFailed copyWith({
    String? id,
    EventWorktreeFailedProperties? properties,
  }) {
    return EventWorktreeFailed(
      id: id ?? this.id,
      properties: properties ?? this.properties,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EventWorktreeFailed &&
          other.id == id &&
          other.properties == properties);

  @override
  int get hashCode => Object.hash(id, properties);

  final String id;
  final EventWorktreeFailedProperties properties;
}

@immutable
class EventWorktreeFailedProperties {
  const EventWorktreeFailedProperties({
    this.message = '',
  });

  factory EventWorktreeFailedProperties.fromJson(Map<String, dynamic> json) {
    return EventWorktreeFailedProperties(
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
  EventWorktreeFailedProperties copyWith({
    String? message,
  }) {
    return EventWorktreeFailedProperties(
      message: message ?? this.message,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EventWorktreeFailedProperties &&
          other.message == message);

  @override
  int get hashCode => message.hashCode;

  final String message;
}
