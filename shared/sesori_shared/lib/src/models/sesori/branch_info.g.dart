// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'branch_info.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_BranchInfo _$BranchInfoFromJson(Map json) => _BranchInfo(
  name: json['name'] as String,
  isRemoteOnly: json['isRemoteOnly'] as bool,
  lastCommitTimestamp: (json['lastCommitTimestamp'] as num?)?.toInt(),
  worktreePath: json['worktreePath'] as String?,
);

Map<String, dynamic> _$BranchInfoToJson(_BranchInfo instance) =>
    <String, dynamic>{
      'name': instance.name,
      'isRemoteOnly': instance.isRemoteOnly,
      'lastCommitTimestamp': instance.lastCommitTimestamp,
      'worktreePath': instance.worktreePath,
    };
