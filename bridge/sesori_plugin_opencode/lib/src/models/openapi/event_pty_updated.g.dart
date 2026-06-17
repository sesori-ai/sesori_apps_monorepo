// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.17.7 (4ed4f749e644ffb5b279fb30b7b915e743d80142)

import 'package:meta/meta.dart';
import 'event.g.dart';
import 'pty.g.dart';

@immutable
class EventPtyUpdated implements Event {
  const EventPtyUpdated({
    required this.id,
    required this.properties,
  });

  factory EventPtyUpdated.fromJson(Map<String, dynamic> json) {
    return EventPtyUpdated(
      id: json["id"] as String,
      properties: EventPtyUpdatedProperties.fromJson(json["properties"] as Map<String, dynamic>),
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "type": "pty.updated",
      "properties": properties.toJson(),
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  EventPtyUpdated copyWith({
    String? id,
    EventPtyUpdatedProperties? properties,
  }) {
    return EventPtyUpdated(
      id: id ?? this.id,
      properties: properties ?? this.properties,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EventPtyUpdated &&
          other.id == id &&
          other.properties == properties);

  @override
  int get hashCode => Object.hash(id, properties);

  final String id;
  final EventPtyUpdatedProperties properties;
}

@immutable
class EventPtyUpdatedProperties {
  const EventPtyUpdatedProperties({
    required this.info,
  });

  factory EventPtyUpdatedProperties.fromJson(Map<String, dynamic> json) {
    return EventPtyUpdatedProperties(
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
  EventPtyUpdatedProperties copyWith({
    Pty? info,
  }) {
    return EventPtyUpdatedProperties(
      info: info ?? this.info,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EventPtyUpdatedProperties &&
          other.info == info);

  @override
  int get hashCode => info.hashCode;

  final Pty info;
}
