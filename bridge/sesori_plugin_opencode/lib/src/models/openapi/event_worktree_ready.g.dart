// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.17.3 (8c8011336163d7e7fb24a6a4a049cdb1f6e6ee74)

import 'package:meta/meta.dart';
import 'event.g.dart';

@immutable
class EventWorktreeReady implements Event {
  const EventWorktreeReady({
    required this.id,
    required this.properties,
  });

  factory EventWorktreeReady.fromJson(Map<String, dynamic> json) {
    return EventWorktreeReady(
      id: json["id"] as String,
      properties: EventWorktreeReadyProperties.fromJson(json["properties"] as Map<String, dynamic>),
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "type": "worktree.ready",
      "properties": properties.toJson(),
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  EventWorktreeReady copyWith({
    String? id,
    EventWorktreeReadyProperties? properties,
  }) {
    return EventWorktreeReady(
      id: id ?? this.id,
      properties: properties ?? this.properties,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EventWorktreeReady &&
          other.id == id &&
          other.properties == properties);

  @override
  int get hashCode => Object.hash(id, properties);

  final String id;
  final EventWorktreeReadyProperties properties;
}

@immutable
class EventWorktreeReadyProperties {
  const EventWorktreeReadyProperties({
    required this.name,
    required this.branch,
  });

  factory EventWorktreeReadyProperties.fromJson(Map<String, dynamic> json) {
    return EventWorktreeReadyProperties(
      name: json["name"] as String,
      branch: json["branch"] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "name": name,
      "branch": ?branch,
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  EventWorktreeReadyProperties copyWith({
    String? name,
    String? branch,
  }) {
    return EventWorktreeReadyProperties(
      name: name ?? this.name,
      branch: branch ?? this.branch,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EventWorktreeReadyProperties &&
          other.name == name &&
          other.branch == branch);

  @override
  int get hashCode => Object.hash(name, branch);

  final String name;
  final String? branch;
}
