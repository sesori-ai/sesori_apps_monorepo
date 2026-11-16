// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v2.3.0 (a6b15d33daf6ab7d35569f6d711fdb630b9f04e7)

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';
import 'permission_rule.g.dart';

/// Type alias for `List<PermissionRule>` decoded from JSON.
@immutable
class PermissionRuleset {
  const PermissionRuleset({required this.items});
  factory PermissionRuleset.fromJson(List<dynamic> json) => PermissionRuleset(items: json.map((e) => PermissionRule.fromJson(e as Map<String, dynamic>)).toList());
  List<dynamic> toJson() => items.map((e) => e.toJson()).toList();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PermissionRuleset &&
          const DeepCollectionEquality().equals(other.items, items));

  @override
  int get hashCode => const DeepCollectionEquality().hash(items);

  final List<PermissionRule> items;
}
