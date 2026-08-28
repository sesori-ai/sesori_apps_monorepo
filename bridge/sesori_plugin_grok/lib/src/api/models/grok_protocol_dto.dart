import "package:freezed_annotation/freezed_annotation.dart";

part "grok_protocol_dto.freezed.dart";
part "grok_protocol_dto.g.dart";

/// One reasoning-effort option advertised in a Grok model's ACP metadata.
@freezed
sealed class GrokReasoningEffortOptionDto with _$GrokReasoningEffortOptionDto {
  const factory({
    required String? id,
    required String? value,
    required String? label,
    required String? description,
    @JsonKey(name: "default") @Default(false) bool isDefault,
  }) = _GrokReasoningEffortOptionDto;

  factory fromJson(Map<String, dynamic> json) => _$GrokReasoningEffortOptionDtoFromJson(json);
}

/// Grok-owned metadata attached to one ACP model entry.
@Freezed(fromJson: true, toJson: false)
sealed class GrokModelMetadataDto with _$GrokModelMetadataDto {
  const factory({
    required bool? supportsReasoningEffort,
    @Default(<GrokReasoningEffortOptionDto>[]) List<GrokReasoningEffortOptionDto> reasoningEfforts,
    required String? reasoningEffort,
  }) = _GrokModelMetadataDto;

  factory fromJson(Map<String, dynamic> json) {
    final sanitized = {...json};
    if (json["supportsReasoningEffort"] is! bool) sanitized["supportsReasoningEffort"] = null;
    if (json["reasoningEffort"] is! String) sanitized["reasoningEffort"] = null;
    final reasoningEfforts = json["reasoningEfforts"];
    if (reasoningEfforts is! List) {
      sanitized.remove("reasoningEfforts");
    } else {
      sanitized["reasoningEfforts"] = reasoningEfforts
          .where(
            (entry) =>
                entry is Map &&
                entry.keys.every((key) => key is String) &&
                (entry["id"] == null || entry["id"] is String) &&
                (entry["value"] == null || entry["value"] is String) &&
                (entry["label"] == null || entry["label"] is String) &&
                (entry["description"] == null || entry["description"] is String) &&
                (entry["default"] == null || entry["default"] is bool),
          )
          .toList(growable: false);
    }
    return _$GrokModelMetadataDtoFromJson(sanitized);
  }
}

/// One model advertised by Grok's legacy ACP model-state surface.
@Freezed(fromJson: true, toJson: false)
sealed class GrokModelInfoDto with _$GrokModelInfoDto {
  const factory({
    required String? modelId,
    required String? name,
    required String? description,
    @JsonKey(name: "_meta") required GrokModelMetadataDto? metadata,
  }) = _GrokModelInfoDto;

  factory fromJson(Map<String, dynamic> json) {
    final sanitized = {...json};
    if (json["modelId"] is! String) sanitized["modelId"] = null;
    if (json["name"] is! String) sanitized["name"] = null;
    if (json["description"] is! String) sanitized["description"] = null;
    final metadata = json["_meta"];
    if (metadata is! Map || !metadata.keys.every((key) => key is String)) sanitized["_meta"] = null;
    return _$GrokModelInfoDtoFromJson(sanitized);
  }
}

/// Current model plus the models available to a Grok ACP session.
@Freezed(fromJson: true, toJson: false)
sealed class GrokSessionModelStateDto with _$GrokSessionModelStateDto {
  const factory({
    @Default(<GrokModelInfoDto>[]) List<GrokModelInfoDto> availableModels,
    required String? currentModelId,
  }) = _GrokSessionModelStateDto;

  factory fromJson(Map<String, dynamic> json) {
    final sanitized = {...json};
    final availableModels = json["availableModels"];
    if (availableModels != null && availableModels is! List) {
      throw const FormatException("Grok availableModels must be a list");
    }
    if (availableModels is List) {
      sanitized["availableModels"] = availableModels
          .where((entry) => entry is Map && entry.keys.every((key) => key is String))
          .toList(growable: false);
    }
    if (json["currentModelId"] is! String) sanitized["currentModelId"] = null;
    return _$GrokSessionModelStateDtoFromJson(sanitized);
  }
}

/// Grok-specific portion of ACP initialize metadata.
@Freezed(fromJson: true, toJson: false)
sealed class GrokInitializeMetadataDto with _$GrokInitializeMetadataDto {
  const factory({
    required bool? grokShell,
    required String? agentVersion,
    required GrokSessionModelStateDto? modelState,
  }) = _GrokInitializeMetadataDto;

  factory fromJson(Map<String, dynamic> json) {
    final sanitized = {...json};
    if (json["grokShell"] is! bool) sanitized["grokShell"] = null;
    if (json["agentVersion"] is! String) sanitized["agentVersion"] = null;
    final modelState = json["modelState"];
    if (modelState is! Map || !modelState.keys.every((key) => key is String)) sanitized["modelState"] = null;
    return _$GrokInitializeMetadataDtoFromJson(sanitized);
  }
}

/// Typed envelope whose caller masks the irrelevant initialize/session branch.
@Freezed(toJson: false)
sealed class GrokModelStateEnvelopeDto with _$GrokModelStateEnvelopeDto {
  const factory({
    @JsonKey(name: "_meta") required GrokInitializeMetadataDto? metadata,
    required GrokSessionModelStateDto? models,
  }) = _GrokModelStateEnvelopeDto;

  factory fromJson(Map<String, dynamic> json) => _$GrokModelStateEnvelopeDtoFromJson(json);
}
