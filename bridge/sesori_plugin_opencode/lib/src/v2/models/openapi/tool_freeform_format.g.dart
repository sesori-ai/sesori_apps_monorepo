// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v2.3.0 (a6b15d33daf6ab7d35569f6d711fdb630b9f04e7)

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
