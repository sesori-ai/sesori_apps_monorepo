// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'gh_pull_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_GhPullRequest _$GhPullRequestFromJson(Map json) => _GhPullRequest(
  number: (json['number'] as num).toInt(),
  url: json['url'] as String,
  title: json['title'] as String,
  state: _prStateFromString(json['state'] as String?),
  headRefName: json['headRefName'] as String,
  mergeable: _prMergeableStatusFromString(json['mergeable'] as String?),
  reviewDecision: _prReviewDecisionFromString(
    json['reviewDecision'] as String?,
  ),
  statusCheckRollup: _prCheckStatusFromRollup(json['statusCheckRollup']),
);

Map<String, dynamic> _$GhPullRequestToJson(_GhPullRequest instance) =>
    <String, dynamic>{
      'number': instance.number,
      'url': instance.url,
      'title': instance.title,
      'state': _$PrStateEnumMap[instance.state]!,
      'headRefName': instance.headRefName,
      'mergeable': _$PrMergeableStatusEnumMap[instance.mergeable]!,
      'reviewDecision': _$PrReviewDecisionEnumMap[instance.reviewDecision]!,
      'statusCheckRollup': _rollupStateToJson(instance.statusCheckRollup),
    };

const _$PrStateEnumMap = {
  PrState.open: 'OPEN',
  PrState.closed: 'CLOSED',
  PrState.merged: 'MERGED',
  PrState.unknown: 'unknown',
};

const _$PrMergeableStatusEnumMap = {
  PrMergeableStatus.mergeable: 'MERGEABLE',
  PrMergeableStatus.conflicted: 'CONFLICTED',
  PrMergeableStatus.unknown: 'UNKNOWN',
};

const _$PrReviewDecisionEnumMap = {
  PrReviewDecision.approved: 'APPROVED',
  PrReviewDecision.changesRequested: 'CHANGES_REQUESTED',
  PrReviewDecision.reviewRequired: 'REVIEW_REQUIRED',
  PrReviewDecision.unknown: 'unknown',
};
