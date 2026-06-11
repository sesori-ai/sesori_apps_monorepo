// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)

import 'package:meta/meta.dart';
import 'event.dart';

@immutable
class EventWorkspaceFailed implements Event {
  const EventWorkspaceFailed({
    required this.id,
    required this.properties,
  });

  factory EventWorkspaceFailed.fromJson(Map<String, dynamic> json) {
    return EventWorkspaceFailed(
      id: json["id"] as String,
      properties: EventWorkspaceFailedProperties.fromJson(json["properties"] as Map<String, dynamic>),
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
    required this.message,
  });

  factory EventWorkspaceFailedProperties.fromJson(Map<String, dynamic> json) {
    return EventWorkspaceFailedProperties(
      message: json["message"] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "message": message,
    };
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
