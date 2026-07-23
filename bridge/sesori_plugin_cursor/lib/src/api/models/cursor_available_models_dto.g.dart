// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'cursor_available_models_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_CursorAvailableModelsDto _$CursorAvailableModelsDtoFromJson(Map json) =>
    _CursorAvailableModelsDto(
      models:
          (json['models'] as List<dynamic>?)
              ?.map(
                (e) => CursorAvailableModelDto.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ),
              )
              .toList() ??
          const <CursorAvailableModelDto>[],
    );

_CursorAvailableModelDto _$CursorAvailableModelDtoFromJson(Map json) =>
    _CursorAvailableModelDto(
      value: json['value'] as String,
      name: json['name'] as String?,
      configOptions:
          (json['configOptions'] as List<dynamic>?)
              ?.map(
                (e) => CursorModelConfigOptionDto.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ),
              )
              .toList() ??
          const <CursorModelConfigOptionDto>[],
    );

_CursorModelConfigOptionDto _$CursorModelConfigOptionDtoFromJson(Map json) =>
    _CursorModelConfigOptionDto(
      id: json['id'] as String,
      name: json['name'] as String?,
      description: json['description'] as String?,
      category: json['category'] as String?,
      currentValue: json['currentValue'] as String?,
      options:
          (json['options'] as List<dynamic>?)
              ?.map(
                (e) => CursorConfigOptionValueDto.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ),
              )
              .toList() ??
          const <CursorConfigOptionValueDto>[],
    );

_CursorConfigOptionValueDto _$CursorConfigOptionValueDtoFromJson(Map json) =>
    _CursorConfigOptionValueDto(
      value: json['value'] as String,
      name: json['name'] as String?,
      description: json['description'] as String?,
    );
