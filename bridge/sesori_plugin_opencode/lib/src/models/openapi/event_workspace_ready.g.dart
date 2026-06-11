// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)

import 'package:meta/meta.dart';
import 'event.g.dart';

@immutable
class EventWorkspaceReady implements Event {
  const EventWorkspaceReady({
    this.id = '',
    required this.properties,
  });

  factory EventWorkspaceReady.fromJson(Map<String, dynamic> json) {
    return EventWorkspaceReady(
      id: (json["id"] ?? '') as String,
      properties: EventWorkspaceReadyProperties.fromJson((json["properties"] ?? const <String, dynamic>{}) as Map<String, dynamic>),
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "type": "workspace.ready",
      "properties": properties.toJson(),
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  EventWorkspaceReady copyWith({
    String? id,
    EventWorkspaceReadyProperties? properties,
  }) {
    return EventWorkspaceReady(
      id: id ?? this.id,
      properties: properties ?? this.properties,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EventWorkspaceReady &&
          other.id == id &&
          other.properties == properties);

  @override
  int get hashCode => Object.hash(id, properties);

  final String id;
  final EventWorkspaceReadyProperties properties;
}

@immutable
class EventWorkspaceReadyProperties {
  const EventWorkspaceReadyProperties({
    this.name = '',
  });

  factory EventWorkspaceReadyProperties.fromJson(Map<String, dynamic> json) {
    return EventWorkspaceReadyProperties(
      name: (json["name"] ?? '') as String,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "name": name,
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  EventWorkspaceReadyProperties copyWith({
    String? name,
  }) {
    return EventWorkspaceReadyProperties(
      name: name ?? this.name,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EventWorkspaceReadyProperties &&
          other.name == name);

  @override
  int get hashCode => name.hashCode;

  final String name;
}
