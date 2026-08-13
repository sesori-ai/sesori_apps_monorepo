import "package:freezed_annotation/freezed_annotation.dart";

part "codex_skill_dto.freezed.dart";
part "codex_skill_dto.g.dart";

@Freezed(fromJson: true, toJson: false)
sealed class CodexSkillsListResponseDto with _$CodexSkillsListResponseDto {
  const factory({
    required List<CodexSkillsListEntryDto> data,
  }) = _CodexSkillsListResponseDto;

  factory fromJson(Map<String, dynamic> json) => _$CodexSkillsListResponseDtoFromJson(json);
}

@Freezed(fromJson: true, toJson: false)
sealed class CodexSkillsListEntryDto with _$CodexSkillsListEntryDto {
  const factory({
    required String cwd,
    required List<CodexSkillDto> skills,
  }) = _CodexSkillsListEntryDto;

  factory fromJson(Map<String, dynamic> json) => _$CodexSkillsListEntryDtoFromJson(json);
}

@Freezed(fromJson: true, toJson: false)
sealed class CodexSkillDto with _$CodexSkillDto {
  const factory({
    required String name,
    required String description,
    required String? shortDescription,
    required CodexSkillInterfaceDto? interface,
    required bool enabled,
  }) = _CodexSkillDto;

  factory fromJson(Map<String, dynamic> json) => _$CodexSkillDtoFromJson(json);
}

@Freezed(fromJson: true, toJson: false)
sealed class CodexSkillInterfaceDto with _$CodexSkillInterfaceDto {
  const factory({
    required String? shortDescription,
  }) = _CodexSkillInterfaceDto;

  factory fromJson(Map<String, dynamic> json) => _$CodexSkillInterfaceDtoFromJson(json);
}
