// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)
// Generated: 2026-06-08T14:11:43.948036Z

import 'package:meta/meta.dart';

@immutable
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
      "tool": ?tool,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PermissionRequest &&
          other.id == id &&
          other.sessionID == sessionID &&
          other.permission == permission &&
          other.patterns == patterns &&
          other.metadata == metadata &&
          other.always == always &&
          other.tool == tool);

  @override
  int get hashCode => Object.hash(id, sessionID, permission, patterns, metadata, always, tool);

  final String id;
  final String sessionID;
  final String permission;
  final List<String> patterns;
  final Map<String, dynamic> metadata;
  final List<String> always;
  final Map<String, dynamic>? tool;
}
