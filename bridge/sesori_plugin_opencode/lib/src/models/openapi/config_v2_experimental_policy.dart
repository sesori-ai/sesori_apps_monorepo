// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)
// Generated: 2026-06-08T14:11:43.917137Z

import 'package:meta/meta.dart';
import 'policy_effect.dart';

@immutable
class ConfigV2ExperimentalPolicy {
  const ConfigV2ExperimentalPolicy({
    required this.action,
    required this.effect,
    required this.resource,
  });

  factory ConfigV2ExperimentalPolicy.fromJson(Map<String, dynamic> json) {
    return ConfigV2ExperimentalPolicy(
      action: json["action"] as String,
      effect: PolicyEffect.fromJson(json["effect"] as String),
      resource: json["resource"] as String,
    );
  }


  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "action": action,
      "effect": effect.toJson(),
      "resource": resource,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ConfigV2ExperimentalPolicy &&
          other.action == action &&
          other.effect == effect &&
          other.resource == resource);

  @override
  int get hashCode => Object.hash(action, effect, resource);

  final String action;
  final PolicyEffect effect;
  final String resource;
}
