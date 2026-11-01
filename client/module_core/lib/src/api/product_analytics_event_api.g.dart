// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'product_analytics_event_api.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Map<String, dynamic> _$ProductAnalyticsEventRequestToJson(
  _ProductAnalyticsEventRequest instance,
) => <String, dynamic>{
  'schemaVersion':
      _$ProductAnalyticsEventSchemaVersionEnumMap[instance.schemaVersion]!,
  'platform': _$ProductAnalyticsEventPlatformEnumMap[instance.platform]!,
  'appVersion': instance.appVersion,
  'name': instance.name,
  'occurredAtMicros': instance.occurredAtMicros,
  'params': instance.params,
};

const _$ProductAnalyticsEventSchemaVersionEnumMap = {
  ProductAnalyticsEventSchemaVersion.v1: 1,
};

const _$ProductAnalyticsEventPlatformEnumMap = {
  ProductAnalyticsEventPlatform.macos: 'MACOS',
  ProductAnalyticsEventPlatform.linux: 'LINUX',
  ProductAnalyticsEventPlatform.windows: 'WINDOWS',
};
