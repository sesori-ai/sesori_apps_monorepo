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
@freezed
sealed class GrokModelMetadataDto with _$GrokModelMetadataDto {
  const factory({
    required bool? supportsReasoningEffort,
    @Default(<GrokReasoningEffortOptionDto>[]) List<GrokReasoningEffortOptionDto> reasoningEfforts,
    required String? reasoningEffort,
  }) = _GrokModelMetadataDto;

  factory fromJson(Map<String, dynamic> json) => _$GrokModelMetadataDtoFromJson(json);
}

/// One model advertised by Grok's legacy ACP model-state surface.
@freezed
sealed class GrokModelInfoDto with _$GrokModelInfoDto {
  const factory({
    required String? modelId,
    required String? name,
    required String? description,
    @JsonKey(name: "_meta") required GrokModelMetadataDto? metadata,
  }) = _GrokModelInfoDto;

  factory fromJson(Map<String, dynamic> json) => _$GrokModelInfoDtoFromJson(json);
}

/// Current model plus the models available to a Grok ACP session.
@freezed
sealed class GrokSessionModelStateDto with _$GrokSessionModelStateDto {
  const factory({
    @Default(<GrokModelInfoDto>[]) List<GrokModelInfoDto> availableModels,
    required String? currentModelId,
  }) = _GrokSessionModelStateDto;

  factory fromJson(Map<String, dynamic> json) => _$GrokSessionModelStateDtoFromJson(json);
}
