import "package:json_annotation/json_annotation.dart";

enum PermissionReply {
  @JsonValue("once")
  once,
  @JsonValue("always")
  always,
  @JsonValue("reject")
  reject,
}
