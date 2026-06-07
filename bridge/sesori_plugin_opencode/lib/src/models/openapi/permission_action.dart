// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)
// Generated: 2026-06-07T10:22:51.665530Z

import 'package:json_annotation/json_annotation.dart';


enum PermissionAction {
  @JsonValue("allow")
  allow,
  @JsonValue("deny")
  deny,
  @JsonValue("ask")
  ask,
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
        throw FormatException('Unknown PermissionAction value: $value');
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
    }
  }
}
