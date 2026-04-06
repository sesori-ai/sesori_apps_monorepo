// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'plugin_provider.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Map<String, dynamic> _$PluginModelToJson(_PluginModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'family': instance.family,
      'isAvailable': instance.isAvailable,
      'releaseDate': const _NullableDateTimeConverter().toJson(
        instance.releaseDate,
      ),
    };

Map<String, dynamic> _$PluginProviderAnthropicToJson(
  PluginProviderAnthropic instance,
) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'authType': _$PluginProviderAuthTypeEnumMap[instance.authType]!,
  'models': instance.models.map((e) => e.toJson()).toList(),
  'defaultModelID': instance.defaultModelID,
  'runtimeType': instance.$type,
};

const _$PluginProviderAuthTypeEnumMap = {
  PluginProviderAuthType.apiKey: 'apiKey',
  PluginProviderAuthType.oauth: 'oauth',
  PluginProviderAuthType.unknown: 'unknown',
};

Map<String, dynamic> _$PluginProviderOpenAIToJson(
  PluginProviderOpenAI instance,
) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'authType': _$PluginProviderAuthTypeEnumMap[instance.authType]!,
  'models': instance.models.map((e) => e.toJson()).toList(),
  'defaultModelID': instance.defaultModelID,
  'runtimeType': instance.$type,
};

Map<String, dynamic> _$PluginProviderGoogleToJson(
  PluginProviderGoogle instance,
) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'authType': _$PluginProviderAuthTypeEnumMap[instance.authType]!,
  'models': instance.models.map((e) => e.toJson()).toList(),
  'defaultModelID': instance.defaultModelID,
  'runtimeType': instance.$type,
};

Map<String, dynamic> _$PluginProviderMistralToJson(
  PluginProviderMistral instance,
) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'authType': _$PluginProviderAuthTypeEnumMap[instance.authType]!,
  'models': instance.models.map((e) => e.toJson()).toList(),
  'defaultModelID': instance.defaultModelID,
  'runtimeType': instance.$type,
};

Map<String, dynamic> _$PluginProviderGroqToJson(PluginProviderGroq instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'authType': _$PluginProviderAuthTypeEnumMap[instance.authType]!,
      'models': instance.models.map((e) => e.toJson()).toList(),
      'defaultModelID': instance.defaultModelID,
      'runtimeType': instance.$type,
    };

Map<String, dynamic> _$PluginProviderXAIToJson(PluginProviderXAI instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'authType': _$PluginProviderAuthTypeEnumMap[instance.authType]!,
      'models': instance.models.map((e) => e.toJson()).toList(),
      'defaultModelID': instance.defaultModelID,
      'runtimeType': instance.$type,
    };

Map<String, dynamic> _$PluginProviderDeepseekToJson(
  PluginProviderDeepseek instance,
) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'authType': _$PluginProviderAuthTypeEnumMap[instance.authType]!,
  'models': instance.models.map((e) => e.toJson()).toList(),
  'defaultModelID': instance.defaultModelID,
  'runtimeType': instance.$type,
};

Map<String, dynamic> _$PluginProviderAmazonBedrockToJson(
  PluginProviderAmazonBedrock instance,
) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'authType': _$PluginProviderAuthTypeEnumMap[instance.authType]!,
  'models': instance.models.map((e) => e.toJson()).toList(),
  'defaultModelID': instance.defaultModelID,
  'runtimeType': instance.$type,
};

Map<String, dynamic> _$PluginProviderAzureToJson(
  PluginProviderAzure instance,
) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'authType': _$PluginProviderAuthTypeEnumMap[instance.authType]!,
  'models': instance.models.map((e) => e.toJson()).toList(),
  'defaultModelID': instance.defaultModelID,
  'runtimeType': instance.$type,
};

Map<String, dynamic> _$PluginProviderCustomToJson(
  PluginProviderCustom instance,
) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'authType': _$PluginProviderAuthTypeEnumMap[instance.authType]!,
  'models': instance.models.map((e) => e.toJson()).toList(),
  'defaultModelID': instance.defaultModelID,
  'runtimeType': instance.$type,
};

Map<String, dynamic> _$PluginProvidersResultToJson(
  _PluginProvidersResult instance,
) => <String, dynamic>{
  'providers': instance.providers.map((e) => e.toJson()).toList(),
};
