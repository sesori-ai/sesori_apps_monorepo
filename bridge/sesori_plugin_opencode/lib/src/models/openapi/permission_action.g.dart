// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.17.3 (8c8011336163d7e7fb24a6a4a049cdb1f6e6ee74)

import 'package:json_annotation/json_annotation.dart';

enum PermissionAction {
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

  static PermissionAction fromJson(String value) {
    switch (value) {
      case "allow":
        return PermissionAction.allow;
      case "deny":
        return PermissionAction.deny;
      case "ask":
        return PermissionAction.ask;
      default:
        return PermissionAction.unknown;
    }
  }

  String toJson() {
    switch (this) {
      case PermissionAction.allow:
        return "allow";
      case PermissionAction.deny:
        return "deny";
      case PermissionAction.ask:
        return "ask";
      case PermissionAction.unknown:
        return 'unknown';
    }
  }
}
