// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)
// Generated: 2026-06-07T10:22:51.669274Z

import 'permission_v2_rule.dart';

/// Type alias for `List<PermissionV2Rule>` decoded from JSON.
class PermissionV2Ruleset {
  const PermissionV2Ruleset({required this.items});
  factory PermissionV2Ruleset.fromJson(List<dynamic> json) => PermissionV2Ruleset(items: json.map((e) => PermissionV2Rule.fromJson(e as Map<String, dynamic>)).toList());
  List<dynamic> toJson() => items.map((e) => e.toJson()).toList();
  final List<PermissionV2Rule> items;
}
