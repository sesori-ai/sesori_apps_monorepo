// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)
// Generated: 2026-06-08T14:11:43.948441Z

import 'package:meta/meta.dart';
import 'permission_action_config.dart';
import 'permission_object_config.dart';

@immutable
abstract interface class PermissionRuleConfig {
  const PermissionRuleConfig();

  /// Serialize the underlying variant. Variants must override this.
  ///
  /// The return type is `Object?` (not `Map<String, dynamic>`)
  /// because some unions are string-or-object and the string
  /// variant encodes as the scalar itself, not a wrapped map.
  /// Callers pass the result straight to `jsonEncode` or
  /// another `toJson()`, both of which accept `Object?`.
  Object? toJson();

  factory PermissionRuleConfig.fromJson(Object json) {
    if (json is String) {
      return permissionRuleConfig00Inline.fromJson(json);
    }
    if (json is Map) {
      return PermissionObjectConfig.fromJson(json as Map<String, dynamic>);
    }
    throw FormatException('Unknown PermissionRuleConfig value: $json');
  }
}

@immutable
class permissionRuleConfig00Inline implements PermissionRuleConfig {
  const permissionRuleConfig00Inline({required this.value});
  factory permissionRuleConfig00Inline.fromJson(String json) {
    return permissionRuleConfig00Inline(value: PermissionActionConfig.fromJson(json));
  }
  @override
  Object? toJson() => value.toJson();
  final PermissionActionConfig value;
}
