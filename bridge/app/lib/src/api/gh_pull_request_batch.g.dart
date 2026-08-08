// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'gh_pull_request_batch.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_GhPullRequestBatchResponse _$GhPullRequestBatchResponseFromJson(Map json) =>
    _GhPullRequestBatchResponse(
      errorCount: (json['errorCount'] as num).toInt(),
      viewerLogin: json['viewerLogin'] as String,
      pages: (json['pages'] as List<dynamic>)
          .map(
            (e) => GhPullRequestCandidatePage.fromJson(
              Map<String, dynamic>.from(e as Map),
            ),
          )
          .toList(),
    );

Map<String, dynamic> _$GhPullRequestBatchResponseToJson(
  _GhPullRequestBatchResponse instance,
) => <String, dynamic>{
  'errorCount': instance.errorCount,
  'viewerLogin': instance.viewerLogin,
  'pages': instance.pages.map((e) => e.toJson()).toList(),
};

_GhPullRequestCandidatePage _$GhPullRequestCandidatePageFromJson(Map json) =>
    _GhPullRequestCandidatePage(
      requestIndex: (json['requestIndex'] as num).toInt(),
      stateGroup: $enumDecode(
        _$GhPullRequestStateGroupEnumMap,
        json['stateGroup'],
      ),
      repositoryIdentity: json['repositoryIdentity'] as String,
      connection: GhPullRequestConnection.fromJson(
        Map<String, dynamic>.from(json['connection'] as Map),
      ),
    );

Map<String, dynamic> _$GhPullRequestCandidatePageToJson(
  _GhPullRequestCandidatePage instance,
) => <String, dynamic>{
  'requestIndex': instance.requestIndex,
  'stateGroup': _$GhPullRequestStateGroupEnumMap[instance.stateGroup]!,
  'repositoryIdentity': instance.repositoryIdentity,
  'connection': instance.connection.toJson(),
};

const _$GhPullRequestStateGroupEnumMap = {
  GhPullRequestStateGroup.open: 'open',
  GhPullRequestStateGroup.terminal: 'terminal',
};

_GhPullRequestConnection _$GhPullRequestConnectionFromJson(Map json) =>
    _GhPullRequestConnection(
      nodes: (json['nodes'] as List<dynamic>)
          .map(
            (e) => GhPullRequest.fromJson(Map<String, dynamic>.from(e as Map)),
          )
          .toList(),
      pageInfo: GhPullRequestPageInfo.fromJson(
        Map<String, dynamic>.from(json['pageInfo'] as Map),
      ),
    );

Map<String, dynamic> _$GhPullRequestConnectionToJson(
  _GhPullRequestConnection instance,
) => <String, dynamic>{
  'nodes': instance.nodes.map((e) => e.toJson()).toList(),
  'pageInfo': instance.pageInfo.toJson(),
};

_GhPullRequestPageInfo _$GhPullRequestPageInfoFromJson(Map json) =>
    _GhPullRequestPageInfo(
      hasNextPage: json['hasNextPage'] as bool,
      endCursor: json['endCursor'] as String?,
    );

Map<String, dynamic> _$GhPullRequestPageInfoToJson(
  _GhPullRequestPageInfo instance,
) => <String, dynamic>{
  'hasNextPage': instance.hasNextPage,
  'endCursor': instance.endCursor,
};
