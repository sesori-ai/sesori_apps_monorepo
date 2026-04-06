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
      'defaultModelID': instance.defaultModelID,
    };

_ProviderModel _$ProviderModelFromJson(Map json) => _ProviderModel(
  id: json['id'] as String,
  providerID: json['providerID'] as String,
  name: json['name'] as String,
  family: json['family'] as String?,
  isAvailable: json['isAvailable'] as bool? ?? true,
  releaseDate: _$JsonConverterFromJson<String, DateTime>(
    json['releaseDate'],
    const DateConverter().fromJson,
  ),
);

Map<String, dynamic> _$ProviderModelToJson(_ProviderModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'providerID': instance.providerID,
      'name': instance.name,
      'family': instance.family,
      'isAvailable': instance.isAvailable,
      'releaseDate': _$JsonConverterToJson<String, DateTime>(
        instance.releaseDate,
        const DateConverter().toJson,
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
