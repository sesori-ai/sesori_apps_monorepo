// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'omp_steering_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_OmpInitializeMetaDto _$OmpInitializeMetaDtoFromJson(Map json) =>
    _OmpInitializeMetaDto(
      meta: json['_meta'] == null
          ? null
          : OmpInitializeExtensionsDto.fromJson(
              Map<String, dynamic>.from(json['_meta'] as Map),
            ),
    );

Map<String, dynamic> _$OmpInitializeMetaDtoToJson(
  _OmpInitializeMetaDto instance,
) => <String, dynamic>{'_meta': ?instance.meta?.toJson()};

_OmpInitializeExtensionsDto _$OmpInitializeExtensionsDtoFromJson(Map json) =>
    _OmpInitializeExtensionsDto(
      steering: json['steering'] == null
          ? null
          : OmpSteeringCapabilityDto.fromJson(
              Map<String, dynamic>.from(json['steering'] as Map),
            ),
    );

Map<String, dynamic> _$OmpInitializeExtensionsDtoToJson(
  _OmpInitializeExtensionsDto instance,
) => <String, dynamic>{'steering': ?instance.steering?.toJson()};

_OmpSteeringCapabilityDto _$OmpSteeringCapabilityDtoFromJson(Map json) =>
    _OmpSteeringCapabilityDto(supported: json['supported'] as bool?);

Map<String, dynamic> _$OmpSteeringCapabilityDtoToJson(
  _OmpSteeringCapabilityDto instance,
) => <String, dynamic>{'supported': ?instance.supported};

Map<String, dynamic> _$OmpSteeringParamsToJson(_OmpSteeringParams instance) =>
    <String, dynamic>{
      'sessionId': instance.sessionId,
      'prompt': instance.prompt,
    };

_OmpSteeringResultDto _$OmpSteeringResultDtoFromJson(Map json) =>
    _OmpSteeringResultDto(
      outcome: $enumDecode(
        _$OmpSteeringOutcomeEnumMap,
        json['outcome'],
        unknownValue: OmpSteeringOutcome.unknown,
      ),
      reason: json['reason'] as String?,
    );

Map<String, dynamic> _$OmpSteeringResultDtoToJson(
  _OmpSteeringResultDto instance,
) => <String, dynamic>{
  'outcome': _$OmpSteeringOutcomeEnumMap[instance.outcome]!,
  'reason': ?instance.reason,
};

const _$OmpSteeringOutcomeEnumMap = {
  OmpSteeringOutcome.injected: 'injected',
  OmpSteeringOutcome.promptRequired: 'promptRequired',
  OmpSteeringOutcome.failed: 'failed',
  OmpSteeringOutcome.unknown: 'unknown',
};
