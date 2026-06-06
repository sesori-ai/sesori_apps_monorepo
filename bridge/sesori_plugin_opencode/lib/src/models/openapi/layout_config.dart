// GENERATED FILE - DO NOT EDIT BY HAND

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
