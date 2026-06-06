// GENERATED FILE - DO NOT EDIT BY HAND

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
