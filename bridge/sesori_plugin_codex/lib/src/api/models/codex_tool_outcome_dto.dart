import "package:freezed_annotation/freezed_annotation.dart";

part "codex_tool_outcome_dto.freezed.dart";
part "codex_tool_outcome_dto.g.dart";

@freezed
sealed class CodexToolOutcomeFileDto with _$CodexToolOutcomeFileDto {
  const factory({
    required int schemaVersion,
    required List<CodexStoredToolErrorDto> errors,
  }) = _CodexToolOutcomeFileDto;

  factory fromJson(Map<String, dynamic> json) => _$CodexToolOutcomeFileDtoFromJson(json);
}

@freezed
sealed class CodexStoredToolErrorDto with _$CodexStoredToolErrorDto {
  const factory({
    required String sessionId,
    required String callId,
  }) = _CodexStoredToolErrorDto;

  factory fromJson(Map<String, dynamic> json) => _$CodexStoredToolErrorDtoFromJson(json);
}
