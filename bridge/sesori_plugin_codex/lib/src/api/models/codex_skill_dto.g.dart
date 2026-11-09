// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'codex_skill_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_CodexSkillsListResponseDto _$CodexSkillsListResponseDtoFromJson(Map json) =>
    _CodexSkillsListResponseDto(
      data: (json['data'] as List<dynamic>)
          .map(
            (e) => CodexSkillsListEntryDto.fromJson(
              Map<String, dynamic>.from(e as Map),
            ),
          )
          .toList(),
    );

_CodexSkillsListEntryDto _$CodexSkillsListEntryDtoFromJson(Map json) =>
    _CodexSkillsListEntryDto(
      cwd: json['cwd'] as String,
      skills: (json['skills'] as List<dynamic>)
          .map(
            (e) => CodexSkillDto.fromJson(Map<String, dynamic>.from(e as Map)),
          )
          .toList(),
    );

_CodexSkillDto _$CodexSkillDtoFromJson(Map json) => _CodexSkillDto(
  name: json['name'] as String,
  description: json['description'] as String,
  shortDescription: json['shortDescription'] as String?,
  interface: json['interface'] == null
      ? null
      : CodexSkillInterfaceDto.fromJson(
          Map<String, dynamic>.from(json['interface'] as Map),
        ),
  enabled: json['enabled'] as bool,
);

_CodexSkillInterfaceDto _$CodexSkillInterfaceDtoFromJson(Map json) =>
    _CodexSkillInterfaceDto(
      shortDescription: json['shortDescription'] as String?,
    );
