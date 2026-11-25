// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'gh_rest_pull_request_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_GhRestPullRequestDto _$GhRestPullRequestDtoFromJson(Map json) => _GhRestPullRequestDto(
  state: $enumDecode(_$GhRestPullRequestStateDtoEnumMap, json['state']),
  merged: json['merged'] as bool,
  title: json['title'] as String,
  head: GhRestHeadDto.fromJson(
    Map<String, dynamic>.from(json['head'] as Map),
  ),
);

const _$GhRestPullRequestStateDtoEnumMap = {
  GhRestPullRequestStateDto.open: 'open',
  GhRestPullRequestStateDto.closed: 'closed',
};

_GhRestHeadDto _$GhRestHeadDtoFromJson(Map json) => _GhRestHeadDto(sha: json['sha'] as String);

_GhMergeResultDto _$GhMergeResultDtoFromJson(Map json) => _GhMergeResultDto(
  merged: json['merged'] as bool?,
  message: json['message'] as String?,
);
