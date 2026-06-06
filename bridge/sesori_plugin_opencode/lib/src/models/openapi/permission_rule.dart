// GENERATED FILE - DO NOT EDIT BY HAND

import 'permission_action.dart';

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

  final String permission;
  final String pattern;
  final PermissionAction action;
}
