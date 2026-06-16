// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.17.3 (8c8011336163d7e7fb24a6a4a049cdb1f6e6ee74)

import 'package:meta/meta.dart';
import 'event.g.dart';
import 'pty.g.dart';

@immutable
class EventPtyCreated implements Event {
  const EventPtyCreated({
    required this.id,
    required this.properties,
  });

  factory EventPtyCreated.fromJson(Map<String, dynamic> json) {
    return EventPtyCreated(
      id: json["id"] as String,
      properties: EventPtyCreatedProperties.fromJson(json["properties"] as Map<String, dynamic>),
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "type": "pty.created",
      "properties": properties.toJson(),
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  EventPtyCreated copyWith({
    String? id,
    EventPtyCreatedProperties? properties,
  }) {
    return EventPtyCreated(
      id: id ?? this.id,
      properties: properties ?? this.properties,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EventPtyCreated &&
          other.id == id &&
          other.properties == properties);

  @override
  int get hashCode => Object.hash(id, properties);

  final String id;
  final EventPtyCreatedProperties properties;
}

@immutable
class EventPtyCreatedProperties {
  const EventPtyCreatedProperties({
    required this.info,
  });

  factory EventPtyCreatedProperties.fromJson(Map<String, dynamic> json) {
    return EventPtyCreatedProperties(
      info: Pty.fromJson(json["info"] as Map<String, dynamic>),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "info": info.toJson(),
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  EventPtyCreatedProperties copyWith({
    Pty? info,
  }) {
    return EventPtyCreatedProperties(
      info: info ?? this.info,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EventPtyCreatedProperties &&
          other.info == info);

  @override
  int get hashCode => info.hashCode;

  final Pty info;
}
