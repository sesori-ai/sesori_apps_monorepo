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

_ProviderModel _$ProviderModelFromJson(Map json) => _ProviderModel(
  id: json['id'] as String,
  providerID: json['providerID'] as String,
  name: json['name'] as String,
  variants: json['variants'] == null
      ? const <String>[]
      : _variantsFromJson(json['variants']),
  family: json['family'] as String?,
  status: json['status'] as String? ?? "active",
  releaseDate: json['release_date'] as String?,
);

_ProviderListResponse _$ProviderListResponseFromJson(Map json) =>
    _ProviderListResponse(
      providers: (_readProvidersJsonKey(json, 'providers') as List<dynamic>)
          .map(
            (e) => ProviderInfo.fromJson(Map<String, dynamic>.from(e as Map)),
          )
          .toList(),
      defaults: Map<String, String>.from(json['default'] as Map),
      connected: (json['connected'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
    );
