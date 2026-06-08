// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)
// Generated: 2026-06-08T14:11:43.948860Z

import 'package:meta/meta.dart';

@immutable
class PermissionSavedInfo {
  const PermissionSavedInfo({
    required this.id,
    required this.projectID,
    required this.action,
    required this.resource,
  });

  factory PermissionSavedInfo.fromJson(Map<String, dynamic> json) {
    return PermissionSavedInfo(
      id: json["id"] as String,
      projectID: json["projectID"] as String,
      action: json["action"] as String,
      resource: json["resource"] as String,
    );
  }


  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "projectID": projectID,
      "action": action,
      "resource": resource,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PermissionSavedInfo &&
          other.id == id &&
          other.projectID == projectID &&
          other.action == action &&
          other.resource == resource);

  @override
  int get hashCode => Object.hash(id, projectID, action, resource);

  final String id;
  final String projectID;
  final String action;
  final String resource;
}
