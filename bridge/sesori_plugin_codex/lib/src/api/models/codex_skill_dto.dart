import "package:freezed_annotation/freezed_annotation.dart";

part "codex_skill_dto.freezed.dart";
part "codex_skill_dto.g.dart";

@Freezed(fromJson: true, toJson: false)
sealed class CodexSkillsListResponseDto with _$CodexSkillsListResponseDto {
  const factory CodexSkillsListResponseDto({
    required List<CodexSkillsListEntryDto> data,
  }) = _CodexSkillsListResponseDto;

  factory CodexSkillsListResponseDto.fromJson(Map<String, dynamic> json) =>
      _$CodexSkillsListResponseDtoFromJson(json);
}

@Freezed(fromJson: true, toJson: false)
sealed class CodexSkillsListEntryDto with _$CodexSkillsListEntryDto {
  const factory CodexSkillsListEntryDto({
    required String cwd,
    required List<CodexSkillDto> skills,
  }) = _CodexSkillsListEntryDto;

  factory CodexSkillsListEntryDto.fromJson(Map<String, dynamic> json) =>
      _$CodexSkillsListEntryDtoFromJson(json);
}

@Freezed(fromJson: true, toJson: false)
sealed class CodexSkillDto with _$CodexSkillDto {
  const factory CodexSkillDto({
    required String name,
    required String description,
    required String? shortDescription,
    required CodexSkillInterfaceDto? interface,
    required bool enabled,
  }) = _CodexSkillDto;

  factory CodexSkillDto.fromJson(Map<String, dynamic> json) =>
      _$CodexSkillDtoFromJson(json);
}

@Freezed(fromJson: true, toJson: false)
sealed class CodexSkillInterfaceDto with _$CodexSkillInterfaceDto {
  const factory CodexSkillInterfaceDto({
    required String? shortDescription,
  }) = _CodexSkillInterfaceDto;

  factory CodexSkillInterfaceDto.fromJson(Map<String, dynamic> json) =>
      _$CodexSkillInterfaceDtoFromJson(json);
}
