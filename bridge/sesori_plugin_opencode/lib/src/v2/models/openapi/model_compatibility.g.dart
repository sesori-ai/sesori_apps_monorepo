// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v2.0.18 (cd9a14a6b688d4021bee381dfd39d2cef9c0f862)

import 'package:meta/meta.dart';
import 'model_max_tokens_field.g.dart';

@immutable
class ModelCompatibility {
  const ModelCompatibility({
    required this.reasoningField,
    required this.requireReasoning,
    required this.maxTokensField,
    required this.requireFinishReason,
    required this.requireAssistantAfterTool,
    required this.supportsPromptCacheKey,
  });

  factory ModelCompatibility.fromJson(Map<String, dynamic> json) {
    return ModelCompatibility(
      reasoningField: json["reasoningField"] as String?,
      requireReasoning: json["requireReasoning"] as bool?,
      maxTokensField: json["maxTokensField"] == null ? null : ModelMaxTokensField.fromJson(json["maxTokensField"] as String),
      requireFinishReason: json["requireFinishReason"] as bool?,
      requireAssistantAfterTool: json["requireAssistantAfterTool"] as bool?,
      supportsPromptCacheKey: json["supportsPromptCacheKey"] as bool?,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "reasoningField": ?reasoningField,
      "requireReasoning": ?requireReasoning,
      "maxTokensField": ?maxTokensField?.toJson(),
      "requireFinishReason": ?requireFinishReason,
      "requireAssistantAfterTool": ?requireAssistantAfterTool,
      "supportsPromptCacheKey": ?supportsPromptCacheKey,
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  ModelCompatibility copyWith({
    String? reasoningField,
    bool? requireReasoning,
    ModelMaxTokensField? maxTokensField,
    bool? requireFinishReason,
    bool? requireAssistantAfterTool,
    bool? supportsPromptCacheKey,
  }) {
    return ModelCompatibility(
      reasoningField: reasoningField ?? this.reasoningField,
      requireReasoning: requireReasoning ?? this.requireReasoning,
      maxTokensField: maxTokensField ?? this.maxTokensField,
      requireFinishReason: requireFinishReason ?? this.requireFinishReason,
      requireAssistantAfterTool: requireAssistantAfterTool ?? this.requireAssistantAfterTool,
      supportsPromptCacheKey: supportsPromptCacheKey ?? this.supportsPromptCacheKey,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ModelCompatibility &&
          other.reasoningField == reasoningField &&
          other.requireReasoning == requireReasoning &&
          other.maxTokensField == maxTokensField &&
          other.requireFinishReason == requireFinishReason &&
          other.requireAssistantAfterTool == requireAssistantAfterTool &&
          other.supportsPromptCacheKey == supportsPromptCacheKey);

  @override
  int get hashCode => Object.hash(reasoningField, requireReasoning, maxTokensField, requireFinishReason, requireAssistantAfterTool, supportsPromptCacheKey);

  final String? reasoningField;
  final bool? requireReasoning;
  final ModelMaxTokensField? maxTokensField;
  final bool? requireFinishReason;
  final bool? requireAssistantAfterTool;
  final bool? supportsPromptCacheKey;
}
