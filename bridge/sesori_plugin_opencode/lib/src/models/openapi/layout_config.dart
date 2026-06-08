// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)
// Generated: 2026-06-08T14:24:06.228511Z

import 'package:json_annotation/json_annotation.dart';

enum LayoutConfig {
  @JsonValue("auto")
  auto,
  @JsonValue("stretch")
  stretch,
  ;

  static LayoutConfig fromJson(String value) {
    switch (value) {
      case "auto":
        return LayoutConfig.auto;
      case "stretch":
        return LayoutConfig.stretch;
      default:
        throw FormatException('Unknown LayoutConfig value: $value');
    }
  }

  String toJson() {
    switch (this) {
      case LayoutConfig.auto:
        return "auto";
      case LayoutConfig.stretch:
        return "stretch";
    }
  }
}
