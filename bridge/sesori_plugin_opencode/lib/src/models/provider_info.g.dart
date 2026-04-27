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
);

Map<String, dynamic> _$ProviderInfoToJson(_ProviderInfo instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'models': instance.models.map((k, e) => MapEntry(k, e.toJson())),
    };

_ProviderModel _$ProviderModelFromJson(Map json) => _ProviderModel(
  id: json['id'] as String,
  providerID: json['providerID'] as String,
  name: json['name'] as String,
  family: json['family'] as String?,
  status: json['status'] as String? ?? "active",
  releaseDate: json['release_date'] as String?,
);

Map<String, dynamic> _$ProviderModelToJson(_ProviderModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'providerID': instance.providerID,
      'name': instance.name,
      'family': instance.family,
      'status': instance.status,
      'release_date': instance.releaseDate,
    };

_ProviderListResponse _$ProviderListResponseFromJson(Map json) =>
    _ProviderListResponse(
      all: (json['all'] as List<dynamic>)
          .map(
            (e) => ProviderInfo.fromJson(Map<String, dynamic>.from(e as Map)),
          )
          .toList(),
      defaults: Map<String, String>.from(json['default'] as Map),
      connected: (json['connected'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
    );

Map<String, dynamic> _$ProviderListResponseToJson(
  _ProviderListResponse instance,
) => <String, dynamic>{
  'all': instance.all.map((e) => e.toJson()).toList(),
  'default': instance.defaults,
  'connected': instance.connected,
};
