// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'antigravity_model_config_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_AntigravityModelConfigDto _$AntigravityModelConfigDtoFromJson(Map json) => _AntigravityModelConfigDto(
  id: json['id'] as String,
  type: $enumDecode(
    _$AntigravityConfigTypeEnumMap,
    json['type'],
    unknownValue: AntigravityConfigType.unknown,
  ),
  currentValue: json['currentValue'] as String,
  options: _modelOptionsFromJson(json['options'] as List),
);

const _$AntigravityConfigTypeEnumMap = {
  AntigravityConfigType.select: 'select',
  AntigravityConfigType.unknown: 'unknown',
};

_AntigravityModelOptionDto _$AntigravityModelOptionDtoFromJson(Map json) => _AntigravityModelOptionDto(
  value: json['value'] as String,
  name: json['name'] as String,
);

_AntigravityModelGroupDto _$AntigravityModelGroupDtoFromJson(Map json) => _AntigravityModelGroupDto(
  options: (json['options'] as List<dynamic>)
      .map(
        (e) => AntigravityModelOptionDto.fromJson(
          Map<String, dynamic>.from(e as Map),
        ),
      )
      .toList(),
);
