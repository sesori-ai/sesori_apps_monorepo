// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)
// Generated: 2026-06-08T09:42:34.344332Z

import 'permission_action_config.dart';
import 'permission_rule_config.dart';

class PermissionObjectConfig implements PermissionRuleConfig {
  const PermissionObjectConfig({required this.value});

  factory PermissionObjectConfig.fromJson(Map<String, dynamic> json) {
    return PermissionObjectConfig(
      value: Map<String, PermissionActionConfig>.from(
        json.map((k, v) => MapEntry(k, PermissionActionConfig.fromJson(v as String))),
      ),
    );
  }

  final Map<String, PermissionActionConfig> value;

  @override
  Map<String, dynamic> toJson() {
    return value.map((k, v) => MapEntry(k, v.toJson()));
  }
}
