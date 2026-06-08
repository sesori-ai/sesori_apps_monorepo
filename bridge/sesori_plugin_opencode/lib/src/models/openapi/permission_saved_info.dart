// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)
// Generated: 2026-06-08T13:32:28.041874Z


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

  final String id;
  final String projectID;
  final String action;
  final String resource;
}
