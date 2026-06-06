// GENERATED FILE - DO NOT EDIT BY HAND


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
