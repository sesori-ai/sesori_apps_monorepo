// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)
// Generated: 2026-06-08T14:24:06.236853Z

import 'package:meta/meta.dart';
import 'permission_action.dart';

@immutable
class PermissionRule {
  const PermissionRule({
    required this.permission,
    required this.pattern,
    required this.action,
  });

  factory PermissionRule.fromJson(Map<String, dynamic> json) {
    return PermissionRule(
      permission: json["permission"] as String,
      pattern: json["pattern"] as String,
      action: PermissionAction.fromJson(json["action"] as String),
    );
  }


  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "permission": permission,
      "pattern": pattern,
      "action": action.toJson(),
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PermissionRule &&
          other.permission == permission &&
          other.pattern == pattern &&
          other.action == action);

  @override
  int get hashCode => Object.hash(permission, pattern, action);

  final String permission;
  final String pattern;
  final PermissionAction action;
}
