// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)
// Generated: 2026-06-08T09:42:34.321990Z

import 'policy_effect.dart';

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

  final String action;
  final PolicyEffect effect;
  final String resource;
}
