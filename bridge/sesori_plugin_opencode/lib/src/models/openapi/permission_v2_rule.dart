// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)
// Generated: 2026-06-08T14:24:06.238009Z

import 'package:meta/meta.dart';
import 'permission_v2_effect.dart';

@immutable
class PermissionV2Rule {
  const PermissionV2Rule({
    required this.action,
    required this.resource,
    required this.effect,
  });

  factory PermissionV2Rule.fromJson(Map<String, dynamic> json) {
    return PermissionV2Rule(
      action: json["action"] as String,
      resource: json["resource"] as String,
      effect: PermissionV2Effect.fromJson(json["effect"] as String),
    );
  }


  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "action": action,
      "resource": resource,
      "effect": effect.toJson(),
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PermissionV2Rule &&
          other.action == action &&
          other.resource == resource &&
          other.effect == effect);

  @override
  int get hashCode => Object.hash(action, resource, effect);

  final String action;
  final String resource;
  final PermissionV2Effect effect;
}
