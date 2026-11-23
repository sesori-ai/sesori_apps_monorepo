// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v2.4.1 (6f0514052a3c859894ad01bb14cc14dda1e44b96)

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
