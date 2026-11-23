// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v2.4.1 (6f0514052a3c859894ad01bb14cc14dda1e44b96)

import 'package:json_annotation/json_annotation.dart';

enum PermissionReply {
  @JsonValue("once")
  once,
  @JsonValue("always")
  always,
  @JsonValue("reject")
  reject,

  /// Fallback for values introduced by newer OpenCode servers.
  /// Encodes back to the literal string `unknown`.
  unknown,
  ;

  static PermissionReply fromJson(String value) {
    switch (value) {
      case "once":
        return PermissionReply.once;
      case "always":
        return PermissionReply.always;
      case "reject":
        return PermissionReply.reject;
      default:
        return PermissionReply.unknown;
    }
  }

  String toJson() {
    switch (this) {
      case PermissionReply.once:
        return "once";
      case PermissionReply.always:
        return "always";
      case PermissionReply.reject:
        return "reject";
      case PermissionReply.unknown:
        return 'unknown';
    }
  }
}
