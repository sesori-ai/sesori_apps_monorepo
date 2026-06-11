// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)

import 'package:collection/collection.dart';
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
      return PermissionRuleConfig00Inline.fromJson(json);
    }
    if (json is Map) {
      return PermissionObjectConfig.fromJson(json as Map<String, dynamic>);
    }
    return PermissionRuleConfigUnknown(raw: json);
  }
}

@immutable
class PermissionRuleConfig00Inline implements PermissionRuleConfig {
  const PermissionRuleConfig00Inline({required this.value});
  factory PermissionRuleConfig00Inline.fromJson(String json) {
    return PermissionRuleConfig00Inline(value: PermissionActionConfig.fromJson(json));
  }
  @override
  Object? toJson() => value.toJson();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PermissionRuleConfig00Inline && other.value == value);

  @override
  int get hashCode => value.hashCode;

  final PermissionActionConfig value;
}


/// Fallback variant for an unrecognized [PermissionRuleConfig] payload shape.
/// Carries the raw JSON so newer OpenCode servers do not break
/// decoding; `toJson` returns the payload unchanged.
@immutable
class PermissionRuleConfigUnknown implements PermissionRuleConfig {
  const PermissionRuleConfigUnknown({required this.raw});

  final Object? raw;

  @override
  Object? toJson() => raw;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PermissionRuleConfigUnknown &&
          const DeepCollectionEquality().equals(other.raw, raw));

  @override
  int get hashCode => const DeepCollectionEquality().hash(raw);
}
