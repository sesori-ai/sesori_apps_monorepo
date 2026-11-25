// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pull_request_baseline.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_PullRequestBaseline _$PullRequestBaselineFromJson(Map json) => _PullRequestBaseline(
  state: $enumDecode(_$PullRequestStateEnumMap, json['state']),
  headSha: json['headSha'] as String,
  mergeable: $enumDecode(_$PullRequestMergeableEnumMap, json['mergeable']),
  ciPhase: $enumDecode(_$PullRequestCiPhaseEnumMap, json['ciPhase']),
  failedCheckIds: (json['failedCheckIds'] as List<dynamic>).map((e) => e as String).toSet(),
  reviewSignature: json['reviewSignature'] as String,
  issueCommentIds: (json['issueCommentIds'] as List<dynamic>).map((e) => e as String).toSet(),
  issueCommentsTotal: (json['issueCommentsTotal'] as num).toInt(),
  reviewSummaryIds: (json['reviewSummaryIds'] as List<dynamic>).map((e) => e as String).toSet(),
  threadCommentIds: (json['threadCommentIds'] as Map).map(
    (k, e) => MapEntry(
      k as String,
      (e as List<dynamic>).map((e) => e as String).toSet(),
    ),
  ),
  resolvedThreadIds: (json['resolvedThreadIds'] as List<dynamic>).map((e) => e as String).toSet(),
  unresolvedThreadCount: (json['unresolvedThreadCount'] as num).toInt(),
);

Map<String, dynamic> _$PullRequestBaselineToJson(
  _PullRequestBaseline instance,
) => <String, dynamic>{
  'state': _$PullRequestStateEnumMap[instance.state]!,
  'headSha': instance.headSha,
  'mergeable': _$PullRequestMergeableEnumMap[instance.mergeable]!,
  'ciPhase': _$PullRequestCiPhaseEnumMap[instance.ciPhase]!,
  'failedCheckIds': instance.failedCheckIds.toList(),
  'reviewSignature': instance.reviewSignature,
  'issueCommentIds': instance.issueCommentIds.toList(),
  'issueCommentsTotal': instance.issueCommentsTotal,
  'reviewSummaryIds': instance.reviewSummaryIds.toList(),
  'threadCommentIds': instance.threadCommentIds.map(
    (k, e) => MapEntry(k, e.toList()),
  ),
  'resolvedThreadIds': instance.resolvedThreadIds.toList(),
  'unresolvedThreadCount': instance.unresolvedThreadCount,
};

const _$PullRequestStateEnumMap = {
  PullRequestState.open: 'open',
  PullRequestState.merged: 'merged',
  PullRequestState.closed: 'closed',
};

const _$PullRequestMergeableEnumMap = {
  PullRequestMergeable.mergeable: 'mergeable',
  PullRequestMergeable.conflicting: 'conflicting',
  PullRequestMergeable.unknown: 'unknown',
};

const _$PullRequestCiPhaseEnumMap = {
  PullRequestCiPhase.none: 'none',
  PullRequestCiPhase.running: 'running',
  PullRequestCiPhase.concluded: 'concluded',
};
