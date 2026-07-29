// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'product_analytics_preference_update_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ProductAnalyticsPreferenceUpdateRequest
_$ProductAnalyticsPreferenceUpdateRequestFromJson(Map json) =>
    _ProductAnalyticsPreferenceUpdateRequest(
      preference: json['preference'] as String,
      expectedRevision: (json['expectedRevision'] as num).toInt(),
      operationId: json['operationId'] as String,
    );

Map<String, dynamic> _$ProductAnalyticsPreferenceUpdateRequestToJson(
  _ProductAnalyticsPreferenceUpdateRequest instance,
) => <String, dynamic>{
  'preference': instance.preference,
  'expectedRevision': instance.expectedRevision,
  'operationId': instance.operationId,
};
