// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)

import 'package:json_annotation/json_annotation.dart';

enum PermissionV2Effect {
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

  static PermissionV2Effect fromJson(String value) {
    switch (value) {
      case "allow":
        return PermissionV2Effect.allow;
      case "deny":
        return PermissionV2Effect.deny;
      case "ask":
        return PermissionV2Effect.ask;
      default:
        return PermissionV2Effect.unknown;
    }
  }

  String toJson() {
    switch (this) {
      case PermissionV2Effect.allow:
        return "allow";
      case PermissionV2Effect.deny:
        return "deny";
      case PermissionV2Effect.ask:
        return "ask";
      case PermissionV2Effect.unknown:
        return 'unknown';
    }
  }
}
