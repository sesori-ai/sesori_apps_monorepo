import "package:freezed_annotation/freezed_annotation.dart";

part "codex_collaboration_mode_dto.freezed.dart";
part "codex_collaboration_mode_dto.g.dart";

@Freezed(fromJson: false, toJson: true)
sealed class CodexCollaborationModeDto with _$CodexCollaborationModeDto {
  const factory CodexCollaborationModeDto({
    required String mode,
    required CodexCollaborationModeSettingsDto settings,
  }) = _CodexCollaborationModeDto;
}

@Freezed(fromJson: false, toJson: true)
sealed class CodexCollaborationModeSettingsDto with _$CodexCollaborationModeSettingsDto {
  const factory CodexCollaborationModeSettingsDto({
    required String model,
    @JsonKey(name: "reasoning_effort") required String? reasoningEffort,
    @JsonKey(name: "developer_instructions") required String? developerInstructions,
  }) = _CodexCollaborationModeSettingsDto;
}
