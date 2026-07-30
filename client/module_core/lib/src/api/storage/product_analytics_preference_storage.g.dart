// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'product_analytics_preference_storage.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

StoredProductAnalyticsSynced _$StoredProductAnalyticsSyncedFromJson(Map json) =>
    StoredProductAnalyticsSynced(
      userId: json['userId'] as String,
      revision: (json['revision'] as num).toInt(),
      userKey: json['userKey'] as String,
      preference: $enumDecode(
        _$ProductAnalyticsPreferenceEnumMap,
        json['preference'],
      ),
      $type: json['kind'] as String?,
    );

Map<String, dynamic> _$StoredProductAnalyticsSyncedToJson(
  StoredProductAnalyticsSynced instance,
) => <String, dynamic>{
  'userId': instance.userId,
  'revision': instance.revision,
  'userKey': instance.userKey,
  'preference': _$ProductAnalyticsPreferenceEnumMap[instance.preference]!,
  'kind': instance.$type,
};

const _$ProductAnalyticsPreferenceEnumMap = {
  ProductAnalyticsPreference.enabled: 'enabled',
  ProductAnalyticsPreference.disabled: 'disabled',
};

StoredProductAnalyticsPendingDisable
_$StoredProductAnalyticsPendingDisableFromJson(Map json) =>
    StoredProductAnalyticsPendingDisable(
      userId: json['userId'] as String,
      revision: (json['revision'] as num).toInt(),
      userKey: json['userKey'] as String,
      operationId: json['operationId'] as String,
      $type: json['kind'] as String?,
    );

Map<String, dynamic> _$StoredProductAnalyticsPendingDisableToJson(
  StoredProductAnalyticsPendingDisable instance,
) => <String, dynamic>{
  'userId': instance.userId,
  'revision': instance.revision,
  'userKey': instance.userKey,
  'operationId': instance.operationId,
  'kind': instance.$type,
};

StoredProductAnalyticsPendingEnable
_$StoredProductAnalyticsPendingEnableFromJson(Map json) =>
    StoredProductAnalyticsPendingEnable(
      userId: json['userId'] as String,
      revision: (json['revision'] as num).toInt(),
      userKey: json['userKey'] as String,
      operationId: json['operationId'] as String,
      $type: json['kind'] as String?,
    );

Map<String, dynamic> _$StoredProductAnalyticsPendingEnableToJson(
  StoredProductAnalyticsPendingEnable instance,
) => <String, dynamic>{
  'userId': instance.userId,
  'revision': instance.revision,
  'userKey': instance.userKey,
  'operationId': instance.operationId,
  'kind': instance.$type,
};
