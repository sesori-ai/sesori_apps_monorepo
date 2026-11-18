// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v2.3.2 (c0ad18b402eb2827fc1ee71c171b1177b3fc02d1)

import 'package:json_annotation/json_annotation.dart';

enum ToolFreeformFormat {
  @JsonValue("text")
  text,
  @JsonValue("regex")
  regex,
  @JsonValue("lark")
  lark,

  /// Fallback for values introduced by newer OpenCode servers.
  /// Encodes back to the literal string `unknown`.
  unknown,
  ;

  static ToolFreeformFormat fromJson(String value) {
    switch (value) {
      case "text":
        return ToolFreeformFormat.text;
      case "regex":
        return ToolFreeformFormat.regex;
      case "lark":
        return ToolFreeformFormat.lark;
      default:
        return ToolFreeformFormat.unknown;
    }
  }

  String toJson() {
    switch (this) {
      case ToolFreeformFormat.text:
        return "text";
      case ToolFreeformFormat.regex:
        return "regex";
      case ToolFreeformFormat.lark:
        return "lark";
      case ToolFreeformFormat.unknown:
        return 'unknown';
    }
  }
}
