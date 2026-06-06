// GENERATED FILE - DO NOT EDIT BY HAND

import 'package:json_annotation/json_annotation.dart';


enum PermissionActionConfig {
  @JsonValue("ask")
  ask,
  @JsonValue("allow")
  allow,
  @JsonValue("deny")
  deny,
  ;

  static PermissionActionConfig fromJson(String value) {
    switch (value) {
      case "ask":
        return PermissionActionConfig.ask;
      case "allow":
        return PermissionActionConfig.allow;
      case "deny":
        return PermissionActionConfig.deny;
      default:
        throw FormatException('Unknown PermissionActionConfig value: $value');
    }
  }

  String toJson() {
    switch (this) {
      case PermissionActionConfig.ask:
        return "ask";
      case PermissionActionConfig.allow:
        return "allow";
      case PermissionActionConfig.deny:
        return "deny";
    }
  }
}
