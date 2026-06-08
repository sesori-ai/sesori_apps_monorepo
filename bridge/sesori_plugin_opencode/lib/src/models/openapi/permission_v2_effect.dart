// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)
// Generated: 2026-06-08T14:04:07.981064Z

import 'package:json_annotation/json_annotation.dart';

enum PermissionV2Effect {
  @JsonValue("allow")
  allow,
  @JsonValue("deny")
  deny,
  @JsonValue("ask")
  ask,
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
        throw FormatException('Unknown PermissionV2Effect value: $value');
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
    }
  }
}
