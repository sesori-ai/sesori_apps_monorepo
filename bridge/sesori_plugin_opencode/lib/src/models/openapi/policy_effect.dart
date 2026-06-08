// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)
// Generated: 2026-06-08T08:11:58.911413Z

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
