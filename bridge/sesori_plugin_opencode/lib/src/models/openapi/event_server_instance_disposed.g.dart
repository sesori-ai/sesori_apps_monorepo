// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.17.7 (4ed4f749e644ffb5b279fb30b7b915e743d80142)

import 'package:meta/meta.dart';
import 'event.g.dart';

@immutable
class EventServerInstanceDisposed implements Event {
  const EventServerInstanceDisposed({
    required this.id,
    required this.properties,
  });

  factory EventServerInstanceDisposed.fromJson(Map<String, dynamic> json) {
    return EventServerInstanceDisposed(
      id: json["id"] as String,
      properties: EventServerInstanceDisposedProperties.fromJson(json["properties"] as Map<String, dynamic>),
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "type": "server.instance.disposed",
      "properties": properties.toJson(),
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  EventServerInstanceDisposed copyWith({
    String? id,
    EventServerInstanceDisposedProperties? properties,
  }) {
    return EventServerInstanceDisposed(
      id: id ?? this.id,
      properties: properties ?? this.properties,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EventServerInstanceDisposed &&
          other.id == id &&
          other.properties == properties);

  @override
  int get hashCode => Object.hash(id, properties);

  final String id;
  final EventServerInstanceDisposedProperties properties;
}

@immutable
class EventServerInstanceDisposedProperties {
  const EventServerInstanceDisposedProperties({
    required this.directory,
  });

  factory EventServerInstanceDisposedProperties.fromJson(Map<String, dynamic> json) {
    return EventServerInstanceDisposedProperties(
      directory: json["directory"] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "directory": directory,
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  EventServerInstanceDisposedProperties copyWith({
    String? directory,
  }) {
    return EventServerInstanceDisposedProperties(
      directory: directory ?? this.directory,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EventServerInstanceDisposedProperties &&
          other.directory == directory);

  @override
  int get hashCode => directory.hashCode;

  final String directory;
}
