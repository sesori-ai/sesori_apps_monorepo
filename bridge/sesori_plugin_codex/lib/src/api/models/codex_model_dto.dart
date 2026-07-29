import "package:freezed_annotation/freezed_annotation.dart";

part "codex_model_dto.freezed.dart";
part "codex_model_dto.g.dart";

@Freezed(fromJson: true, toJson: false)
sealed class CodexModelListResponseDto with _$CodexModelListResponseDto {
  const factory CodexModelListResponseDto({
    required List<CodexModelDto> data,
    required String? nextCursor,
  }) = _CodexModelListResponseDto;

  factory CodexModelListResponseDto.fromJson(Map<String, dynamic> json) => _$CodexModelListResponseDtoFromJson(json);
}

@Freezed(fromJson: true, toJson: false)
sealed class CodexModelDto with _$CodexModelDto {
  const factory CodexModelDto({
    required String? id,
    required String? displayName,
    required bool? hidden,
    required List<CodexReasoningEffortOptionDto>? supportedReasoningEfforts,
    required String? defaultReasoningEffort,
    required bool? isDefault,
  }) = _CodexModelDto;

  factory CodexModelDto.fromJson(Map<String, dynamic> json) => _$CodexModelDtoFromJson(json);
}

@Freezed(fromJson: true, toJson: false)
sealed class CodexReasoningEffortOptionDto with _$CodexReasoningEffortOptionDto {
  const factory CodexReasoningEffortOptionDto({
    required String? reasoningEffort,
    required String? description,
  }) = _CodexReasoningEffortOptionDto;

  factory CodexReasoningEffortOptionDto.fromJson(
    Map<String, dynamic> json,
  ) => _$CodexReasoningEffortOptionDtoFromJson(json);
}
