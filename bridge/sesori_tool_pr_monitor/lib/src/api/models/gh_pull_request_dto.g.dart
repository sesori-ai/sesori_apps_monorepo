// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'gh_pull_request_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_GhPullRequestDto _$GhPullRequestDtoFromJson(Map json) => _GhPullRequestDto(
  title: json['title'] as String,
  url: json['url'] as String,
  state: $enumDecode(_$GhPullRequestStateDtoEnumMap, json['state']),
  mergeable: $enumDecode(
    _$GhMergeableStateDtoEnumMap,
    json['mergeable'],
    unknownValue: GhMergeableStateDto.unknown,
  ),
  headRefOid: json['headRefOid'] as String,
  commits: GhCommitConnectionDto.fromJson(
    Map<String, dynamic>.from(json['commits'] as Map),
  ),
  reviewRequests: GhReviewRequestConnectionDto.fromJson(
    Map<String, dynamic>.from(json['reviewRequests'] as Map),
  ),
  latestReviews: GhReviewConnectionDto.fromJson(
    Map<String, dynamic>.from(json['latestReviews'] as Map),
  ),
  reviewThreads: GhReviewThreadConnectionDto.fromJson(
    Map<String, dynamic>.from(json['reviewThreads'] as Map),
  ),
  comments: GhIssueCommentConnectionDto.fromJson(
    Map<String, dynamic>.from(json['comments'] as Map),
  ),
  labels: GhLabelConnectionDto.fromJson(
    Map<String, dynamic>.from(json['labels'] as Map),
  ),
);

const _$GhPullRequestStateDtoEnumMap = {
  GhPullRequestStateDto.open: 'OPEN',
  GhPullRequestStateDto.merged: 'MERGED',
  GhPullRequestStateDto.closed: 'CLOSED',
};

const _$GhMergeableStateDtoEnumMap = {
  GhMergeableStateDto.mergeable: 'MERGEABLE',
  GhMergeableStateDto.conflicting: 'CONFLICTING',
  GhMergeableStateDto.unknown: 'UNKNOWN',
};

_GhPageInfoDto _$GhPageInfoDtoFromJson(Map json) => _GhPageInfoDto(
  hasNextPage: json['hasNextPage'] as bool,
  endCursor: json['endCursor'] as String?,
);

_GhCommitConnectionDto _$GhCommitConnectionDtoFromJson(Map json) => _GhCommitConnectionDto(
  nodes: (json['nodes'] as List<dynamic>)
      .map(
        (e) => GhCommitNodeDto.fromJson(Map<String, dynamic>.from(e as Map)),
      )
      .toList(),
);

_GhCommitNodeDto _$GhCommitNodeDtoFromJson(Map json) => _GhCommitNodeDto(
  commit: GhCommitDto.fromJson(
    Map<String, dynamic>.from(json['commit'] as Map),
  ),
);

_GhCommitDto _$GhCommitDtoFromJson(Map json) => _GhCommitDto(
  statusCheckRollup: json['statusCheckRollup'] == null
      ? null
      : GhStatusCheckRollupDto.fromJson(
          Map<String, dynamic>.from(json['statusCheckRollup'] as Map),
        ),
);

_GhStatusCheckRollupDto _$GhStatusCheckRollupDtoFromJson(Map json) => _GhStatusCheckRollupDto(
  contexts: GhCheckContextConnectionDto.fromJson(
    Map<String, dynamic>.from(json['contexts'] as Map),
  ),
);

_GhCheckContextConnectionDto _$GhCheckContextConnectionDtoFromJson(Map json) => _GhCheckContextConnectionDto(
  pageInfo: GhPageInfoDto.fromJson(
    Map<String, dynamic>.from(json['pageInfo'] as Map),
  ),
  nodes: (json['nodes'] as List<dynamic>)
      .map(
        (e) => GhCheckContextDto.fromJson(Map<String, dynamic>.from(e as Map)),
      )
      .toList(),
);

GhCheckRunDto _$GhCheckRunDtoFromJson(Map json) => GhCheckRunDto(
  id: json['id'] as String,
  name: json['name'] as String,
  status: $enumDecode(
    _$GhCheckStatusDtoEnumMap,
    json['status'],
    unknownValue: GhCheckStatusDto.unknown,
  ),
  conclusion: $enumDecodeNullable(
    _$GhCheckConclusionDtoEnumMap,
    json['conclusion'],
    unknownValue: GhCheckConclusionDto.unknown,
  ),
  $type: json['__typename'] as String?,
);

const _$GhCheckStatusDtoEnumMap = {
  GhCheckStatusDto.completed: 'COMPLETED',
  GhCheckStatusDto.unknown: 'UNKNOWN',
};

const _$GhCheckConclusionDtoEnumMap = {
  GhCheckConclusionDto.success: 'SUCCESS',
  GhCheckConclusionDto.neutral: 'NEUTRAL',
  GhCheckConclusionDto.skipped: 'SKIPPED',
  GhCheckConclusionDto.unknown: 'UNKNOWN',
};

GhStatusContextDto _$GhStatusContextDtoFromJson(Map json) => GhStatusContextDto(
  context: json['context'] as String,
  state: $enumDecode(
    _$GhStatusStateDtoEnumMap,
    json['state'],
    unknownValue: GhStatusStateDto.unknown,
  ),
  createdAt: DateTime.parse(json['createdAt'] as String),
  $type: json['__typename'] as String?,
);

const _$GhStatusStateDtoEnumMap = {
  GhStatusStateDto.success: 'SUCCESS',
  GhStatusStateDto.pending: 'PENDING',
  GhStatusStateDto.expected: 'EXPECTED',
  GhStatusStateDto.unknown: 'UNKNOWN',
};

GhUnknownCheckContextDto _$GhUnknownCheckContextDtoFromJson(Map json) =>
    GhUnknownCheckContextDto($type: json['__typename'] as String?);

_GhReviewRequestConnectionDto _$GhReviewRequestConnectionDtoFromJson(
  Map json,
) => _GhReviewRequestConnectionDto(
  nodes: (json['nodes'] as List<dynamic>)
      .map(
        (e) => GhReviewRequestDto.fromJson(Map<String, dynamic>.from(e as Map)),
      )
      .toList(),
);

_GhReviewRequestDto _$GhReviewRequestDtoFromJson(Map json) => _GhReviewRequestDto(
  requestedReviewer: json['requestedReviewer'] == null
      ? null
      : GhRequestedReviewerDto.fromJson(
          Map<String, dynamic>.from(json['requestedReviewer'] as Map),
        ),
);

_GhRequestedReviewerDto _$GhRequestedReviewerDtoFromJson(Map json) => _GhRequestedReviewerDto(
  login: json['login'] as String?,
  slug: json['slug'] as String?,
);

_GhReviewConnectionDto _$GhReviewConnectionDtoFromJson(Map json) => _GhReviewConnectionDto(
  pageInfo: GhPageInfoDto.fromJson(
    Map<String, dynamic>.from(json['pageInfo'] as Map),
  ),
  nodes: (json['nodes'] as List<dynamic>)
      .map((e) => GhReviewDto.fromJson(Map<String, dynamic>.from(e as Map)))
      .toList(),
);

_GhReviewDto _$GhReviewDtoFromJson(Map json) => _GhReviewDto(
  id: json['id'] as String,
  author: json['author'] == null ? null : GhActorDto.fromJson(Map<String, dynamic>.from(json['author'] as Map)),
  state: $enumDecode(
    _$GhReviewStateDtoEnumMap,
    json['state'],
    unknownValue: GhReviewStateDto.unknown,
  ),
  submittedAt: json['submittedAt'] == null ? null : DateTime.parse(json['submittedAt'] as String),
  body: json['body'] as String,
  comments: GhTotalCountDto.fromJson(
    Map<String, dynamic>.from(json['comments'] as Map),
  ),
);

const _$GhReviewStateDtoEnumMap = {
  GhReviewStateDto.pending: 'PENDING',
  GhReviewStateDto.commented: 'COMMENTED',
  GhReviewStateDto.approved: 'APPROVED',
  GhReviewStateDto.changesRequested: 'CHANGES_REQUESTED',
  GhReviewStateDto.dismissed: 'DISMISSED',
  GhReviewStateDto.unknown: 'UNKNOWN',
};

_GhReviewThreadConnectionDto _$GhReviewThreadConnectionDtoFromJson(Map json) => _GhReviewThreadConnectionDto(
  pageInfo: GhPageInfoDto.fromJson(
    Map<String, dynamic>.from(json['pageInfo'] as Map),
  ),
  nodes: (json['nodes'] as List<dynamic>)
      .map(
        (e) => GhReviewThreadDto.fromJson(Map<String, dynamic>.from(e as Map)),
      )
      .toList(),
);

_GhReviewThreadDto _$GhReviewThreadDtoFromJson(Map json) => _GhReviewThreadDto(
  id: json['id'] as String,
  isResolved: json['isResolved'] as bool,
  path: json['path'] as String?,
  line: (json['line'] as num?)?.toInt(),
  originalLine: (json['originalLine'] as num?)?.toInt(),
  comments: GhThreadCommentConnectionDto.fromJson(
    Map<String, dynamic>.from(json['comments'] as Map),
  ),
);

_GhThreadCommentConnectionDto _$GhThreadCommentConnectionDtoFromJson(
  Map json,
) => _GhThreadCommentConnectionDto(
  nodes: (json['nodes'] as List<dynamic>)
      .map((e) => GhCommentDto.fromJson(Map<String, dynamic>.from(e as Map)))
      .toList(),
);

_GhIssueCommentConnectionDto _$GhIssueCommentConnectionDtoFromJson(Map json) => _GhIssueCommentConnectionDto(
  totalCount: (json['totalCount'] as num).toInt(),
  nodes: (json['nodes'] as List<dynamic>)
      .map(
        (e) => GhCommentDto.fromJson(Map<String, dynamic>.from(e as Map)),
      )
      .toList(),
);

_GhCommentDto _$GhCommentDtoFromJson(Map json) => _GhCommentDto(
  id: json['id'] as String,
  author: json['author'] == null ? null : GhActorDto.fromJson(Map<String, dynamic>.from(json['author'] as Map)),
  body: json['body'] as String,
  createdAt: DateTime.parse(json['createdAt'] as String),
  pullRequestReview: json['pullRequestReview'] == null
      ? null
      : GhCommentReviewDto.fromJson(
          Map<String, dynamic>.from(json['pullRequestReview'] as Map),
        ),
);

_GhCommentReviewDto _$GhCommentReviewDtoFromJson(Map json) => _GhCommentReviewDto(
  state: $enumDecode(
    _$GhReviewStateDtoEnumMap,
    json['state'],
    unknownValue: GhReviewStateDto.unknown,
  ),
);

_GhActorDto _$GhActorDtoFromJson(Map json) => _GhActorDto(
  login: json['login'] as String,
  kind: $enumDecode(
    _$GhActorKindDtoEnumMap,
    json['__typename'],
    unknownValue: GhActorKindDto.other,
  ),
);

const _$GhActorKindDtoEnumMap = {
  GhActorKindDto.bot: 'Bot',
  GhActorKindDto.other: 'other',
};

_GhTotalCountDto _$GhTotalCountDtoFromJson(Map json) =>
    _GhTotalCountDto(totalCount: (json['totalCount'] as num).toInt());

_GhLabelConnectionDto _$GhLabelConnectionDtoFromJson(Map json) => _GhLabelConnectionDto(
  pageInfo: GhPageInfoDto.fromJson(
    Map<String, dynamic>.from(json['pageInfo'] as Map),
  ),
  nodes: (json['nodes'] as List<dynamic>).map((e) => GhLabelDto.fromJson(Map<String, dynamic>.from(e as Map))).toList(),
);

_GhLabelDto _$GhLabelDtoFromJson(Map json) => _GhLabelDto(name: json['name'] as String);
