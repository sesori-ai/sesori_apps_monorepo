// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)

import 'package:meta/meta.dart';
import 'event.dart';

@immutable
class EventPtyExited implements Event {
  const EventPtyExited({
    required this.id,
    required this.properties,
  });

  factory EventPtyExited.fromJson(Map<String, dynamic> json) {
    return EventPtyExited(
      id: json["id"] as String,
      properties: EventPtyExitedProperties.fromJson(json["properties"] as Map<String, dynamic>),
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
    required this.id,
    required this.exitCode,
  });

  factory EventPtyExitedProperties.fromJson(Map<String, dynamic> json) {
    return EventPtyExitedProperties(
      id: json["id"] as String,
      exitCode: (json["exitCode"] as num).toInt(),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "exitCode": exitCode,
    };
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
