// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.17.3 (8c8011336163d7e7fb24a6a4a049cdb1f6e6ee74)

import 'package:meta/meta.dart';
import 'event.g.dart';

@immutable
class EventPtyDeleted implements Event {
  const EventPtyDeleted({
    this.id = '',
    required this.properties,
  });

  factory EventPtyDeleted.fromJson(Map<String, dynamic> json) {
    return EventPtyDeleted(
      id: (json["id"] ?? '') as String,
      properties: EventPtyDeletedProperties.fromJson((json["properties"] ?? const <String, dynamic>{}) as Map<String, dynamic>),
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "type": "pty.deleted",
      "properties": properties.toJson(),
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  EventPtyDeleted copyWith({
    String? id,
    EventPtyDeletedProperties? properties,
  }) {
    return EventPtyDeleted(
      id: id ?? this.id,
      properties: properties ?? this.properties,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EventPtyDeleted &&
          other.id == id &&
          other.properties == properties);

  @override
  int get hashCode => Object.hash(id, properties);

  final String id;
  final EventPtyDeletedProperties properties;
}

@immutable
class EventPtyDeletedProperties {
  const EventPtyDeletedProperties({
    this.id = '',
  });

  factory EventPtyDeletedProperties.fromJson(Map<String, dynamic> json) {
    return EventPtyDeletedProperties(
      id: (json["id"] ?? '') as String,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  EventPtyDeletedProperties copyWith({
    String? id,
  }) {
    return EventPtyDeletedProperties(
      id: id ?? this.id,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EventPtyDeletedProperties &&
          other.id == id);

  @override
  int get hashCode => id.hashCode;

  final String id;
}
