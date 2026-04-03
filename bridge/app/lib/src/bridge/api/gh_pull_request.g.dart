// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'gh_pull_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_GhPullRequest _$GhPullRequestFromJson(Map json) => _GhPullRequest(
  number: (json['number'] as num).toInt(),
  url: json['url'] as String,
  title: json['title'] as String,
  state: json['state'] as String,
  headRefName: json['headRefName'] as String,
  mergeable: json['mergeable'] as String?,
  reviewDecision: json['reviewDecision'] as String?,
  statusCheckRollup: _extractRollupState(json['statusCheckRollup']),
);

Map<String, dynamic> _$GhPullRequestToJson(_GhPullRequest instance) =>
    <String, dynamic>{
      'number': instance.number,
      'url': instance.url,
      'title': instance.title,
      'state': instance.state,
      'headRefName': instance.headRefName,
      'mergeable': instance.mergeable,
      'reviewDecision': instance.reviewDecision,
      'statusCheckRollup': instance.statusCheckRollup,
    };
