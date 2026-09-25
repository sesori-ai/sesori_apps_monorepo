// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v2.0.16 (3a103fe0aff726a4edc7492f03f7b88195d9e4c9)

import 'package:json_annotation/json_annotation.dart';

enum PermissionEffect {
  @JsonValue("allow")
  allow,
  @JsonValue("deny")
  deny,
  @JsonValue("ask")
  ask,

  /// Fallback for values introduced by newer OpenCode servers.
  /// Encodes back to the literal string `unknown`.
  unknown,
  ;

  static PermissionEffect fromJson(String value) {
    switch (value) {
      case "allow":
        return PermissionEffect.allow;
      case "deny":
        return PermissionEffect.deny;
      case "ask":
        return PermissionEffect.ask;
      default:
        return PermissionEffect.unknown;
    }
  }

  String toJson() {
    switch (this) {
      case PermissionEffect.allow:
        return "allow";
      case PermissionEffect.deny:
        return "deny";
      case PermissionEffect.ask:
        return "ask";
      case PermissionEffect.unknown:
        return 'unknown';
    }
  }
}
