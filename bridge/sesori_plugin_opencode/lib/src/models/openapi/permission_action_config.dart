// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)

import 'package:json_annotation/json_annotation.dart';

enum PermissionActionConfig {
  @JsonValue("ask")
  ask,
  @JsonValue("allow")
  allow,
  @JsonValue("deny")
  deny,

  /// Fallback for values introduced by newer OpenCode servers.
  /// Encodes back to the literal string `unknown`.
  unknown,
  ;

  static PermissionActionConfig fromJson(String value) {
    switch (value) {
      case "ask":
        return PermissionActionConfig.ask;
      case "allow":
        return PermissionActionConfig.allow;
      case "deny":
        return PermissionActionConfig.deny;
      default:
        return PermissionActionConfig.unknown;
    }
  }

  String toJson() {
    switch (this) {
      case PermissionActionConfig.ask:
        return "ask";
      case PermissionActionConfig.allow:
        return "allow";
      case PermissionActionConfig.deny:
        return "deny";
      case PermissionActionConfig.unknown:
        return 'unknown';
    }
  }
}
