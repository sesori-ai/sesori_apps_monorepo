// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)

import 'package:meta/meta.dart';
import 'event.g.dart';

@immutable
class EventPtyExited implements Event {
  const EventPtyExited({
    this.id = '',
    required this.properties,
  });

  factory EventPtyExited.fromJson(Map<String, dynamic> json) {
    return EventPtyExited(
      id: (json["id"] ?? '') as String,
      properties: EventPtyExitedProperties.fromJson((json["properties"] ?? const <String, dynamic>{}) as Map<String, dynamic>),
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "type": "pty.exited",
      "properties": properties.toJson(),
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  EventPtyExited copyWith({
    String? id,
    EventPtyExitedProperties? properties,
  }) {
    return EventPtyExited(
      id: id ?? this.id,
      properties: properties ?? this.properties,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EventPtyExited &&
          other.id == id &&
          other.properties == properties);

  @override
  int get hashCode => Object.hash(id, properties);

  final String id;
  final EventPtyExitedProperties properties;
}

@immutable
class EventPtyExitedProperties {
  const EventPtyExitedProperties({
    this.id = '',
    this.exitCode = 0,
  });

  factory EventPtyExitedProperties.fromJson(Map<String, dynamic> json) {
    return EventPtyExitedProperties(
      id: (json["id"] ?? '') as String,
      exitCode: ((json["exitCode"] ?? 0) as num).toInt(),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "exitCode": exitCode,
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  EventPtyExitedProperties copyWith({
    String? id,
    int? exitCode,
  }) {
    return EventPtyExitedProperties(
      id: id ?? this.id,
      exitCode: exitCode ?? this.exitCode,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EventPtyExitedProperties &&
          other.id == id &&
          other.exitCode == exitCode);

  @override
  int get hashCode => Object.hash(id, exitCode);

  final String id;
  final int exitCode;
}
