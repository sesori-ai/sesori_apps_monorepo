// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.17.7 (4ed4f749e644ffb5b279fb30b7b915e743d80142)

import 'package:meta/meta.dart';
import 'permission_action.g.dart';

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

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  PermissionRule copyWith({
    String? permission,
    String? pattern,
    PermissionAction? action,
  }) {
    return PermissionRule(
      permission: permission ?? this.permission,
      pattern: pattern ?? this.pattern,
      action: action ?? this.action,
    );
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
