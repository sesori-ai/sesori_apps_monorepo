// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v2.4.2 (fc31a485317970bcf6be7b431a9830aaef875731)

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
