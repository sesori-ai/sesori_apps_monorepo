// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'product_analytics_preference_api.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ProductAnalyticsPreferenceApiRecord
_$ProductAnalyticsPreferenceApiRecordFromJson(Map json) =>
    _ProductAnalyticsPreferenceApiRecord(
      preference: $enumDecode(
        _$ProductAnalyticsPreferenceEnumMap,
        json['preference'],
      ),
      revision: (json['revision'] as num).toInt(),
      userKey: json['userKey'] as String,
    );

Map<String, dynamic> _$ProductAnalyticsPreferenceApiRecordToJson(
  _ProductAnalyticsPreferenceApiRecord instance,
) => <String, dynamic>{
  'preference': _$ProductAnalyticsPreferenceEnumMap[instance.preference]!,
  'revision': instance.revision,
  'userKey': instance.userKey,
};

const _$ProductAnalyticsPreferenceEnumMap = {
  ProductAnalyticsPreference.enabled: 'enabled',
  ProductAnalyticsPreference.disabled: 'disabled',
};

_ProductAnalyticsPreferenceConflictResponse
_$ProductAnalyticsPreferenceConflictResponseFromJson(Map json) =>
    _ProductAnalyticsPreferenceConflictResponse(
      error: $enumDecode(
        _$ProductAnalyticsPreferenceConflictErrorEnumMap,
        json['error'],
      ),
      preference: $enumDecode(
        _$ProductAnalyticsPreferenceEnumMap,
        json['preference'],
      ),
      revision: (json['revision'] as num).toInt(),
      userKey: json['userKey'] as String,
    );

const _$ProductAnalyticsPreferenceConflictErrorEnumMap = {
  ProductAnalyticsPreferenceConflictError.conflict: 'conflict',
};
