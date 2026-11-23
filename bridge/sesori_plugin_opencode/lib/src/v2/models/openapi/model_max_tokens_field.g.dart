// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v2.4.1 (6f0514052a3c859894ad01bb14cc14dda1e44b96)

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
