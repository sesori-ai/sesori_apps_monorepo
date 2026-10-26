// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v2.1.4 (68bc26b7da1990ce10ffecfbc1e09eb13aa5d824)

import 'package:meta/meta.dart';
import 'model_cache_format.g.dart';
import 'model_max_tokens_field.g.dart';

@immutable
class ProviderCompatibility {
  const ProviderCompatibility({
    required this.reasoningField,
    required this.requireReasoning,
    required this.maxTokensField,
    required this.requireFinishReason,
    required this.requireAssistantAfterTool,
    required this.supportsPromptCacheKey,
    required this.streamUsage,
    required this.cacheFormat,
  });

  factory ProviderCompatibility.fromJson(Map<String, dynamic> json) {
    return ProviderCompatibility(
      reasoningField: json["reasoningField"] as String?,
      requireReasoning: json["requireReasoning"] as bool?,
      maxTokensField: json["maxTokensField"] == null ? null : ModelMaxTokensField.fromJson(json["maxTokensField"] as String),
      requireFinishReason: json["requireFinishReason"] as bool?,
      requireAssistantAfterTool: json["requireAssistantAfterTool"] as bool?,
      supportsPromptCacheKey: json["supportsPromptCacheKey"] as bool?,
      streamUsage: json["streamUsage"] as bool?,
      cacheFormat: json["cacheFormat"] == null ? null : ModelCacheFormat.fromJson(json["cacheFormat"] as String),
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
      "streamUsage": ?streamUsage,
      "cacheFormat": ?cacheFormat?.toJson(),
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  ProviderCompatibility copyWith({
    String? reasoningField,
    bool? requireReasoning,
    ModelMaxTokensField? maxTokensField,
    bool? requireFinishReason,
    bool? requireAssistantAfterTool,
    bool? supportsPromptCacheKey,
    bool? streamUsage,
    ModelCacheFormat? cacheFormat,
  }) {
    return ProviderCompatibility(
      reasoningField: reasoningField ?? this.reasoningField,
      requireReasoning: requireReasoning ?? this.requireReasoning,
      maxTokensField: maxTokensField ?? this.maxTokensField,
      requireFinishReason: requireFinishReason ?? this.requireFinishReason,
      requireAssistantAfterTool: requireAssistantAfterTool ?? this.requireAssistantAfterTool,
      supportsPromptCacheKey: supportsPromptCacheKey ?? this.supportsPromptCacheKey,
      streamUsage: streamUsage ?? this.streamUsage,
      cacheFormat: cacheFormat ?? this.cacheFormat,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ProviderCompatibility &&
          other.reasoningField == reasoningField &&
          other.requireReasoning == requireReasoning &&
          other.maxTokensField == maxTokensField &&
          other.requireFinishReason == requireFinishReason &&
          other.requireAssistantAfterTool == requireAssistantAfterTool &&
          other.supportsPromptCacheKey == supportsPromptCacheKey &&
          other.streamUsage == streamUsage &&
          other.cacheFormat == cacheFormat);

  @override
  int get hashCode => Object.hash(reasoningField, requireReasoning, maxTokensField, requireFinishReason, requireAssistantAfterTool, supportsPromptCacheKey, streamUsage, cacheFormat);

  final String? reasoningField;
  final bool? requireReasoning;
  final ModelMaxTokensField? maxTokensField;
  final bool? requireFinishReason;
  final bool? requireAssistantAfterTool;
  final bool? supportsPromptCacheKey;
  final bool? streamUsage;
  final ModelCacheFormat? cacheFormat;
}
