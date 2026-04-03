// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pull_request_info.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_PullRequestInfo _$PullRequestInfoFromJson(Map json) => _PullRequestInfo(
  number: (json['number'] as num).toInt(),
  url: json['url'] as String,
  title: json['title'] as String,
  state: $enumDecode(
    _$PrStateEnumMap,
    json['state'],
    unknownValue: PrState.unknown,
  ),
  mergeableStatus: $enumDecode(
    _$PrMergeableStatusEnumMap,
    json['mergeableStatus'],
    unknownValue: PrMergeableStatus.unknown,
  ),
  reviewDecision: $enumDecode(
    _$PrReviewDecisionEnumMap,
    json['reviewDecision'],
    unknownValue: PrReviewDecision.unknown,
  ),
  checkStatus: $enumDecode(
    _$PrCheckStatusEnumMap,
    json['checkStatus'],
    unknownValue: PrCheckStatus.unknown,
  ),
);

Map<String, dynamic> _$PullRequestInfoToJson(_PullRequestInfo instance) =>
    <String, dynamic>{
      'number': instance.number,
      'url': instance.url,
      'title': instance.title,
      'state': _$PrStateEnumMap[instance.state]!,
      'mergeableStatus': _$PrMergeableStatusEnumMap[instance.mergeableStatus]!,
      'reviewDecision': _$PrReviewDecisionEnumMap[instance.reviewDecision]!,
      'checkStatus': _$PrCheckStatusEnumMap[instance.checkStatus]!,
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

const _$PrCheckStatusEnumMap = {
  PrCheckStatus.success: 'SUCCESS',
  PrCheckStatus.failure: 'FAILURE',
  PrCheckStatus.pending: 'PENDING',
  PrCheckStatus.unknown: 'unknown',
};
