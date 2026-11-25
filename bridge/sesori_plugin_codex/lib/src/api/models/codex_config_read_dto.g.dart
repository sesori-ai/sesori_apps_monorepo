// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'codex_config_read_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_CodexConfigReadResponseDto _$CodexConfigReadResponseDtoFromJson(Map json) =>
    _CodexConfigReadResponseDto(
      config: CodexEffectiveConfigDto.fromJson(
        Map<String, dynamic>.from(json['config'] as Map),
      ),
    );

_CodexEffectiveConfigDto _$CodexEffectiveConfigDtoFromJson(Map json) =>
    _CodexEffectiveConfigDto(
      developerInstructions: json['developer_instructions'] as String?,
    );
