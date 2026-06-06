// GENERATED FILE - DO NOT EDIT BY HAND

import 'package:json_annotation/json_annotation.dart';


enum PolicyEffect {
  @JsonValue("allow")
  allow,
  @JsonValue("deny")
  deny,
  ;

  static PolicyEffect fromJson(String value) {
    switch (value) {
      case "allow":
        return PolicyEffect.allow;
      case "deny":
        return PolicyEffect.deny;
      default:
        throw FormatException('Unknown PolicyEffect value: $value');
    }
  }

  String toJson() {
    switch (this) {
      case PolicyEffect.allow:
        return "allow";
      case PolicyEffect.deny:
        return "deny";
    }
  }
}
