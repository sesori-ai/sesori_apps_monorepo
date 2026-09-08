// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'plugin_provider.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Map<String, dynamic> _$PluginModelToJson(_PluginModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'variants': instance.variants,
      'defaultVariant': ?instance.defaultVariant,
      'family': ?instance.family,
      'isAvailable': instance.isAvailable,
      'releaseDate': ?instance.releaseDate?.toIso8601String(),
    };

Map<String, dynamic> _$PluginProviderToJson(_PluginProvider instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'authType': _$PluginProviderAuthTypeEnumMap[instance.authType]!,
      'models': instance.models.map((e) => e.toJson()).toList(),
      'defaultModelID': ?instance.defaultModelID,
    };

const _$PluginProviderAuthTypeEnumMap = {
  PluginProviderAuthType.apiKey: 'apiKey',
  PluginProviderAuthType.oauth: 'oauth',
  PluginProviderAuthType.unknown: 'unknown',
};

Map<String, dynamic> _$PluginProvidersResultToJson(
  _PluginProvidersResult instance,
) => <String, dynamic>{
  'providers': instance.providers.map((e) => e.toJson()).toList(),
};
