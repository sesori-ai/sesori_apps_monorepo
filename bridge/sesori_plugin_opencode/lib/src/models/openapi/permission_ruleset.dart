// GENERATED FILE - DO NOT EDIT BY HAND

import 'permission_rule.dart';

/// Type alias for `List<PermissionRule>` decoded from JSON.
class PermissionRuleset {
  const PermissionRuleset({required this.items});
  factory PermissionRuleset.fromJson(List<dynamic> json) => PermissionRuleset(items: json.map((e) => PermissionRule.fromJson(e as Map<String, dynamic>)).toList());
  List<dynamic> toJson() => items.map((e) => e.toJson()).toList();
  final List<PermissionRule> items;
}
