// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pull_request_info.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_PullRequestInfo _$PullRequestInfoFromJson(Map json) => _PullRequestInfo(
  number: (json['number'] as num).toInt(),
  url: json['url'] as String,
  title: json['title'] as String,
  state: json['state'] as String,
  mergeableStatus: json['mergeableStatus'] as String?,
  reviewDecision: json['reviewDecision'] as String?,
  checkStatus: json['checkStatus'] as String?,
);

Map<String, dynamic> _$PullRequestInfoToJson(_PullRequestInfo instance) =>
    <String, dynamic>{
      'number': instance.number,
      'url': instance.url,
      'title': instance.title,
      'state': instance.state,
      'mergeableStatus': instance.mergeableStatus,
      'reviewDecision': instance.reviewDecision,
      'checkStatus': instance.checkStatus,
    };
