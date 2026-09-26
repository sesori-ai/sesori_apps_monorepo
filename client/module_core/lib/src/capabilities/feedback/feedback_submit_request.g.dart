// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'feedback_submit_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_FeedbackSubmitRequest _$FeedbackSubmitRequestFromJson(Map json) =>
    _FeedbackSubmitRequest(
      issues: (json['issues'] as List<dynamic>)
          .map((e) => $enumDecode(_$FeedbackIssueEnumMap, e))
          .toList(),
      message: json['message'] as String?,
      source: $enumDecode(_$FeedbackSourceEnumMap, json['source']),
      platform: $enumDecode(_$DevicePlatformEnumMap, json['platform']),
      appVersion: json['appVersion'] as String,
    );

Map<String, dynamic> _$FeedbackSubmitRequestToJson(
  _FeedbackSubmitRequest instance,
) => <String, dynamic>{
  'issues': instance.issues.map((e) => _$FeedbackIssueEnumMap[e]!).toList(),
  'message': ?instance.message,
  'source': _$FeedbackSourceEnumMap[instance.source]!,
  'platform': _$DevicePlatformEnumMap[instance.platform]!,
  'appVersion': instance.appVersion,
};

const _$FeedbackIssueEnumMap = {
  FeedbackIssue.hardToNavigate: 'hard_to_navigate',
  FeedbackIssue.connectionDrops: 'connection_drops',
  FeedbackIssue.notificationsMissing: 'notifications_missing',
  FeedbackIssue.appSlow: 'app_slow',
};

const _$FeedbackSourceEnumMap = {
  FeedbackSource.automatic: 'automatic',
  FeedbackSource.settings: 'settings',
};

const _$DevicePlatformEnumMap = {
  DevicePlatform.ios: 'ios',
  DevicePlatform.android: 'android',
  DevicePlatform.macos: 'macos',
};
