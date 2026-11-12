// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v2.2.7 (fedc6f208aa2bd54c1019227214568083f6380ad)

import 'package:meta/meta.dart';
import 'model_cache_format.g.dart';
import 'model_max_tokens_field.g.dart';
import 'model_media_input.g.dart';

@immutable
class ModelCompatibility {
  const ModelCompatibility({
    required this.reasoningField,
    required this.requireReasoning,
    required this.maxTokensField,
    required this.requireFinishReason,
    required this.requireAssistantAfterTool,
    required this.supportsPromptCacheKey,
    required this.streamUsage,
    required this.cacheFormat,
    required this.supportsThinkingBlockBinding,
    required this.supportsEffortUpdates,
    required this.mediaInput,
  });

  factory ModelCompatibility.fromJson(Map<String, dynamic> json) {
    return ModelCompatibility(
      reasoningField: json["reasoningField"] as String?,
      requireReasoning: json["requireReasoning"] as bool?,
      maxTokensField: json["maxTokensField"] == null ? null : ModelMaxTokensField.fromJson(json["maxTokensField"] as String),
      requireFinishReason: json["requireFinishReason"] as bool?,
      requireAssistantAfterTool: json["requireAssistantAfterTool"] as bool?,
      supportsPromptCacheKey: json["supportsPromptCacheKey"] as bool?,
      streamUsage: json["streamUsage"] as bool?,
      cacheFormat: json["cacheFormat"] == null ? null : ModelCacheFormat.fromJson(json["cacheFormat"] as String),
      supportsThinkingBlockBinding: json["supportsThinkingBlockBinding"] as bool?,
      supportsEffortUpdates: json["supportsEffortUpdates"] as bool?,
      mediaInput: json["mediaInput"] == null ? null : ModelMediaInput.fromJson(json["mediaInput"] as String),
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
      "supportsThinkingBlockBinding": ?supportsThinkingBlockBinding,
      "supportsEffortUpdates": ?supportsEffortUpdates,
      "mediaInput": ?mediaInput?.toJson(),
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
    bool? streamUsage,
    ModelCacheFormat? cacheFormat,
    bool? supportsThinkingBlockBinding,
    bool? supportsEffortUpdates,
    ModelMediaInput? mediaInput,
  }) {
    return ModelCompatibility(
      reasoningField: reasoningField ?? this.reasoningField,
      requireReasoning: requireReasoning ?? this.requireReasoning,
      maxTokensField: maxTokensField ?? this.maxTokensField,
      requireFinishReason: requireFinishReason ?? this.requireFinishReason,
      requireAssistantAfterTool: requireAssistantAfterTool ?? this.requireAssistantAfterTool,
      supportsPromptCacheKey: supportsPromptCacheKey ?? this.supportsPromptCacheKey,
      streamUsage: streamUsage ?? this.streamUsage,
      cacheFormat: cacheFormat ?? this.cacheFormat,
      supportsThinkingBlockBinding: supportsThinkingBlockBinding ?? this.supportsThinkingBlockBinding,
      supportsEffortUpdates: supportsEffortUpdates ?? this.supportsEffortUpdates,
      mediaInput: mediaInput ?? this.mediaInput,
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
          other.supportsPromptCacheKey == supportsPromptCacheKey &&
          other.streamUsage == streamUsage &&
          other.cacheFormat == cacheFormat &&
          other.supportsThinkingBlockBinding == supportsThinkingBlockBinding &&
          other.supportsEffortUpdates == supportsEffortUpdates &&
          other.mediaInput == mediaInput);

  @override
  int get hashCode => Object.hash(reasoningField, requireReasoning, maxTokensField, requireFinishReason, requireAssistantAfterTool, supportsPromptCacheKey, streamUsage, cacheFormat, supportsThinkingBlockBinding, supportsEffortUpdates, mediaInput);

  final String? reasoningField;
  final bool? requireReasoning;
  final ModelMaxTokensField? maxTokensField;
  final bool? requireFinishReason;
  final bool? requireAssistantAfterTool;
  final bool? supportsPromptCacheKey;
  final bool? streamUsage;
  final ModelCacheFormat? cacheFormat;
  final bool? supportsThinkingBlockBinding;
  final bool? supportsEffortUpdates;
  final ModelMediaInput? mediaInput;
}
