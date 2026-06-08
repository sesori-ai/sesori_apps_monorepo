// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)
// Generated: 2026-06-08T09:42:34.345364Z

import 'package:json_annotation/json_annotation.dart';


enum PermissionV2Reply {
  @JsonValue("once")
  once,
  @JsonValue("always")
  always,
  @JsonValue("reject")
  reject,
  ;

  static PermissionV2Reply fromJson(String value) {
    switch (value) {
      case "once":
        return PermissionV2Reply.once;
      case "always":
        return PermissionV2Reply.always;
      case "reject":
        return PermissionV2Reply.reject;
      default:
        throw FormatException('Unknown PermissionV2Reply value: $value');
    }
  }

  String toJson() {
    switch (this) {
      case PermissionV2Reply.once:
        return "once";
      case PermissionV2Reply.always:
        return "always";
      case PermissionV2Reply.reject:
        return "reject";
    }
  }
}
