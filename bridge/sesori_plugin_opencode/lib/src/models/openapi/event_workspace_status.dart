// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)

import 'package:meta/meta.dart';
import 'event.dart';

@immutable
class EventWorkspaceStatus implements Event {
  const EventWorkspaceStatus({
    required this.id,
    required this.properties,
  });

  factory EventWorkspaceStatus.fromJson(Map<String, dynamic> json) {
    return EventWorkspaceStatus(
      id: json["id"] as String,
      properties: EventWorkspaceStatusProperties.fromJson(json["properties"] as Map<String, dynamic>),
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "type": "workspace.status",
      "properties": properties.toJson(),
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EventWorkspaceStatus &&
          other.id == id &&
          other.properties == properties);

  @override
  int get hashCode => Object.hash(id, properties);

  final String id;
  final EventWorkspaceStatusProperties properties;
}

@immutable
class EventWorkspaceStatusProperties {
  const EventWorkspaceStatusProperties({
    required this.workspaceID,
    required this.status,
  });

  factory EventWorkspaceStatusProperties.fromJson(Map<String, dynamic> json) {
    return EventWorkspaceStatusProperties(
      workspaceID: json["workspaceID"] as String,
      status: json["status"] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "workspaceID": workspaceID,
      "status": status,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EventWorkspaceStatusProperties &&
          other.workspaceID == workspaceID &&
          other.status == status);

  @override
  int get hashCode => Object.hash(workspaceID, status);

  final String workspaceID;
  final String status;
}
