// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v2.4.1 (6f0514052a3c859894ad01bb14cc14dda1e44b96)

import 'package:meta/meta.dart';
import 'permission_effect.g.dart';

@immutable
class PermissionRule {
  const PermissionRule({
    required this.action,
    required this.resource,
    required this.effect,
  });

  factory PermissionRule.fromJson(Map<String, dynamic> json) {
    return PermissionRule(
      action: json["action"] as String,
      resource: json["resource"] as String,
      effect: PermissionEffect.fromJson(json["effect"] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "action": action,
      "resource": resource,
      "effect": effect.toJson(),
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  PermissionRule copyWith({
    String? action,
    String? resource,
    PermissionEffect? effect,
  }) {
    return PermissionRule(
      action: action ?? this.action,
      resource: resource ?? this.resource,
      effect: effect ?? this.effect,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PermissionRule &&
          other.action == action &&
          other.resource == resource &&
          other.effect == effect);

  @override
  int get hashCode => Object.hash(action, resource, effect);

  final String action;
  final String resource;
  final PermissionEffect effect;
}
