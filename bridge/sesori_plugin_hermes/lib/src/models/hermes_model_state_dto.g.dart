// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'hermes_model_state_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_HermesModelInfoDto _$HermesModelInfoDtoFromJson(Map json) =>
    _HermesModelInfoDto(
      modelId: json['modelId'] as String?,
      name: json['name'] as String?,
      description: json['description'] as String?,
    );

Map<String, dynamic> _$HermesModelInfoDtoToJson(_HermesModelInfoDto instance) =>
    <String, dynamic>{
      'modelId': ?instance.modelId,
      'name': ?instance.name,
      'description': ?instance.description,
    };

_HermesSessionModelStateDto _$HermesSessionModelStateDtoFromJson(Map json) =>
    _HermesSessionModelStateDto(
      availableModels:
          (json['availableModels'] as List<dynamic>?)
              ?.map(
                (e) => HermesModelInfoDto.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ),
              )
              .toList() ??
          const <HermesModelInfoDto>[],
      currentModelId: json['currentModelId'] as String?,
    );

Map<String, dynamic> _$HermesSessionModelStateDtoToJson(
  _HermesSessionModelStateDto instance,
) => <String, dynamic>{
  'availableModels': instance.availableModels.map((e) => e.toJson()).toList(),
  'currentModelId': ?instance.currentModelId,
};
