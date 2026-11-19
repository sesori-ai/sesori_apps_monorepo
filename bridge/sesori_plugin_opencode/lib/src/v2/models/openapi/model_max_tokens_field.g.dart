// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v2.3.2 (c0ad18b402eb2827fc1ee71c171b1177b3fc02d1)

import 'package:json_annotation/json_annotation.dart';

enum ModelMaxTokensField {
  @JsonValue("max_completion_tokens")
  maxCompletionTokens,
  @JsonValue("max_tokens")
  maxTokens,

  /// Fallback for values introduced by newer OpenCode servers.
  /// Encodes back to the literal string `unknown`.
  unknown,
  ;

  static ModelMaxTokensField fromJson(String value) {
    switch (value) {
      case "max_completion_tokens":
        return ModelMaxTokensField.maxCompletionTokens;
      case "max_tokens":
        return ModelMaxTokensField.maxTokens;
      default:
        return ModelMaxTokensField.unknown;
    }
  }

  String toJson() {
    switch (this) {
      case ModelMaxTokensField.maxCompletionTokens:
        return "max_completion_tokens";
      case ModelMaxTokensField.maxTokens:
        return "max_tokens";
      case ModelMaxTokensField.unknown:
        return 'unknown';
    }
  }
}
