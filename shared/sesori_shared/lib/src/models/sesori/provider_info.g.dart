// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'provider_info.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ProviderInfo _$ProviderInfoFromJson(Map json) => _ProviderInfo(
  id: json['id'] as String,
  name: json['name'] as String,
  models: (json['models'] as Map).map(
    (k, e) => MapEntry(
      k as String,
      ProviderModel.fromJson(Map<String, dynamic>.from(e as Map)),
    ),
  ),
  defaultModelID: json['defaultModelID'] as String?,
);

Map<String, dynamic> _$ProviderInfoToJson(_ProviderInfo instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'models': instance.models.map((k, e) => MapEntry(k, e.toJson())),
      'defaultModelID': ?instance.defaultModelID,
    };

_ProviderModel _$ProviderModelFromJson(Map json) => _ProviderModel(
  id: json['id'] as String,
  providerID: json['providerID'] as String,
  name: json['name'] as String,
  variants: (json['variants'] as List<dynamic>)
      .map((e) => e as String)
      .toList(),
  defaultVariant: json['defaultVariant'] as String?,
  family: json['family'] as String?,
  isAvailable: json['isAvailable'] as bool? ?? true,
  fastMode: json['fastMode'] == null
      ? null
      : FastModeSupport.fromJson(
          Map<String, dynamic>.from(json['fastMode'] as Map),
        ),
  releaseDate: _$JsonConverterFromJson<String, DateTime>(
    json['releaseDate'],
    dateConverter.fromJson,
  ),
);

Map<String, dynamic> _$ProviderModelToJson(_ProviderModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'providerID': instance.providerID,
      'name': instance.name,
      'variants': instance.variants,
      'defaultVariant': ?instance.defaultVariant,
      'family': ?instance.family,
      'isAvailable': instance.isAvailable,
      'fastMode': ?instance.fastMode?.toJson(),
      'releaseDate': ?_$JsonConverterToJson<String, DateTime>(
        instance.releaseDate,
        dateConverter.toJson,
      ),
    };

Value? _$JsonConverterFromJson<Json, Value>(
  Object? json,
  Value? Function(Json json) fromJson,
) => json == null ? null : fromJson(json as Json);

Json? _$JsonConverterToJson<Json, Value>(
  Value? value,
  Json? Function(Value value) toJson,
) => value == null ? null : toJson(value);

FastModeAvailable _$FastModeAvailableFromJson(Map json) => FastModeAvailable(
  promptCacheTtlSeconds: (json['promptCacheTtlSeconds'] as num).toInt(),
  $type: json['type'] as String?,
);

Map<String, dynamic> _$FastModeAvailableToJson(FastModeAvailable instance) =>
    <String, dynamic>{
      'promptCacheTtlSeconds': instance.promptCacheTtlSeconds,
      'type': instance.$type,
    };

FastModeUnavailable _$FastModeUnavailableFromJson(Map json) =>
    FastModeUnavailable(
      reason: $enumDecode(
        _$FastModeUnavailableReasonEnumMap,
        json['reason'],
        unknownValue: FastModeUnavailableReason.unknown,
      ),
      $type: json['type'] as String?,
    );

Map<String, dynamic> _$FastModeUnavailableToJson(
  FastModeUnavailable instance,
) => <String, dynamic>{
  'reason': _$FastModeUnavailableReasonEnumMap[instance.reason]!,
  'type': instance.$type,
};

const _$FastModeUnavailableReasonEnumMap = {
  FastModeUnavailableReason.extraUsageDisabled: 'extraUsageDisabled',
  FastModeUnavailableReason.notOnPlan: 'notOnPlan',
  FastModeUnavailableReason.disabledByOrganization: 'disabledByOrganization',
  FastModeUnavailableReason.unknown: 'unknown',
};

FastModeSupportUnknown _$FastModeSupportUnknownFromJson(Map json) =>
    FastModeSupportUnknown($type: json['type'] as String?);

Map<String, dynamic> _$FastModeSupportUnknownToJson(
  FastModeSupportUnknown instance,
) => <String, dynamic>{'type': instance.$type};

_ProviderListResponse _$ProviderListResponseFromJson(Map json) =>
    _ProviderListResponse(
      items: (json['items'] as List<dynamic>)
          .map(
            (e) => ProviderInfo.fromJson(Map<String, dynamic>.from(e as Map)),
          )
          .toList(),
      connectedOnly: json['connectedOnly'] as bool,
    );

Map<String, dynamic> _$ProviderListResponseToJson(
  _ProviderListResponse instance,
) => <String, dynamic>{
  'items': instance.items.map((e) => e.toJson()).toList(),
  'connectedOnly': instance.connectedOnly,
};
