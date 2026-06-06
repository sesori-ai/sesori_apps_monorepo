// GENERATED FILE - DO NOT EDIT BY HAND

import 'permission_action_config.dart';
import 'permission_object_config.dart';

abstract interface class PermissionRuleConfig {
  const PermissionRuleConfig();

  /// Serialize the underlying variant. Variants must override this.
  Map<String, dynamic> toJson();

  factory PermissionRuleConfig.fromJson(dynamic json) {
    if (json is String) {
      return permissionRuleConfig00Inline.fromJson(json);
    }
    if (json is Map) {
      return PermissionObjectConfig.fromJson(json as Map<String, dynamic>);
    }
    throw FormatException('Unknown PermissionRuleConfig value: $json');
  }
}

class permissionRuleConfig00Inline implements PermissionRuleConfig {
  const permissionRuleConfig00Inline({required this.value});
  factory permissionRuleConfig00Inline.fromJson(String json) {
    return permissionRuleConfig00Inline(value: PermissionActionConfig.fromJson(json));
  }
  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
        'value': value.toJson(),
      };
  final PermissionActionConfig value;
}
