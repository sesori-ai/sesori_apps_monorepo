// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'base_branch_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_BaseBranchResponse _$BaseBranchResponseFromJson(Map json) =>
    _BaseBranchResponse(
      baseBranch: json['baseBranch'] as String?,
      repoSlug: json['repoSlug'] as String?,
      repoHost: json['repoHost'] as String?,
    );

Map<String, dynamic> _$BaseBranchResponseToJson(_BaseBranchResponse instance) =>
    <String, dynamic>{
      'baseBranch': ?instance.baseBranch,
      'repoSlug': ?instance.repoSlug,
      'repoHost': ?instance.repoHost,
    };
