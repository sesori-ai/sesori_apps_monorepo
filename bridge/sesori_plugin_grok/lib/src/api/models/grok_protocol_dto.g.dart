// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'grok_protocol_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_GrokReasoningEffortOptionDto _$GrokReasoningEffortOptionDtoFromJson(
  Map json,
) => _GrokReasoningEffortOptionDto(
  id: json['id'] as String?,
  value: json['value'] as String?,
  label: json['label'] as String?,
  description: json['description'] as String?,
  isDefault: json['default'] as bool? ?? false,
);

Map<String, dynamic> _$GrokReasoningEffortOptionDtoToJson(
  _GrokReasoningEffortOptionDto instance,
) => <String, dynamic>{
  'id': ?instance.id,
  'value': ?instance.value,
  'label': ?instance.label,
  'description': ?instance.description,
  'default': instance.isDefault,
};

_GrokModelMetadataDto _$GrokModelMetadataDtoFromJson(Map json) =>
    _GrokModelMetadataDto(
      supportsReasoningEffort: json['supportsReasoningEffort'] as bool?,
      reasoningEfforts:
          (json['reasoningEfforts'] as List<dynamic>?)
              ?.map(
                (e) => GrokReasoningEffortOptionDto.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ),
              )
              .toList() ??
          const <GrokReasoningEffortOptionDto>[],
      reasoningEffort: json['reasoningEffort'] as String?,
    );

Map<String, dynamic> _$GrokModelMetadataDtoToJson(
  _GrokModelMetadataDto instance,
) => <String, dynamic>{
  'supportsReasoningEffort': ?instance.supportsReasoningEffort,
  'reasoningEfforts': instance.reasoningEfforts.map((e) => e.toJson()).toList(),
  'reasoningEffort': ?instance.reasoningEffort,
};

_GrokModelInfoDto _$GrokModelInfoDtoFromJson(Map json) => _GrokModelInfoDto(
  modelId: json['modelId'] as String?,
  name: json['name'] as String?,
  description: json['description'] as String?,
  metadata: json['_meta'] == null
      ? null
      : GrokModelMetadataDto.fromJson(
          Map<String, dynamic>.from(json['_meta'] as Map),
        ),
);

Map<String, dynamic> _$GrokModelInfoDtoToJson(_GrokModelInfoDto instance) =>
    <String, dynamic>{
      'modelId': ?instance.modelId,
      'name': ?instance.name,
      'description': ?instance.description,
      '_meta': ?instance.metadata?.toJson(),
    };

_GrokSessionModelStateDto _$GrokSessionModelStateDtoFromJson(Map json) =>
    _GrokSessionModelStateDto(
      availableModels:
          (json['availableModels'] as List<dynamic>?)
              ?.map(
                (e) => GrokModelInfoDto.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ),
              )
              .toList() ??
          const <GrokModelInfoDto>[],
      currentModelId: json['currentModelId'] as String?,
    );

Map<String, dynamic> _$GrokSessionModelStateDtoToJson(
  _GrokSessionModelStateDto instance,
) => <String, dynamic>{
  'availableModels': instance.availableModels.map((e) => e.toJson()).toList(),
  'currentModelId': ?instance.currentModelId,
};

_GrokInitializeMetadataDto _$GrokInitializeMetadataDtoFromJson(Map json) =>
    _GrokInitializeMetadataDto(
      grokShell: json['grokShell'] as bool?,
      agentVersion: json['agentVersion'] as String?,
      modelState: json['modelState'] == null
          ? null
          : GrokSessionModelStateDto.fromJson(
              Map<String, dynamic>.from(json['modelState'] as Map),
            ),
    );

_GrokModelStateEnvelopeDto _$GrokModelStateEnvelopeDtoFromJson(Map json) =>
    _GrokModelStateEnvelopeDto(
      metadata: json['_meta'] == null
          ? null
          : GrokInitializeMetadataDto.fromJson(
              Map<String, dynamic>.from(json['_meta'] as Map),
            ),
      models: json['models'] == null
          ? null
          : GrokSessionModelStateDto.fromJson(
              Map<String, dynamic>.from(json['models'] as Map),
            ),
    );
