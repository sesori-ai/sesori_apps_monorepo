// GENERATED FILE - DO NOT EDIT BY HAND


class PermissionRequest {
  const PermissionRequest({
    required this.id,
    required this.sessionID,
    required this.permission,
    required this.patterns,
    required this.metadata,
    required this.always,
    this.tool,
  });

  factory PermissionRequest.fromJson(Map<String, dynamic> json) {
    return PermissionRequest(
      id: json["id"] as String,
      sessionID: json["sessionID"] as String,
      permission: json["permission"] as String,
      patterns: (json["patterns"] as List<dynamic>).cast<String>(),
      metadata: json["metadata"] as Map<String, dynamic>,
      always: (json["always"] as List<dynamic>).cast<String>(),
      tool: json["tool"] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "sessionID": sessionID,
      "permission": permission,
      "patterns": patterns,
      "metadata": metadata,
      "always": always,
      "tool": tool,
    };
  }

  final String id;
  final String sessionID;
  final String permission;
  final List<String> patterns;
  final Map<String, dynamic> metadata;
  final List<String> always;
  final Map<String, dynamic>? tool;
}
