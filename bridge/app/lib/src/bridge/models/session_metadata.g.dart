// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'session_metadata.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_SessionMetadata _$SessionMetadataFromJson(Map json) => _SessionMetadata(
  title: json['title'] as String,
  branchName: json['branchName'] as String,
  worktreeName: json['worktreeName'] as String,
);

Map<String, dynamic> _$SessionMetadataToJson(_SessionMetadata instance) =>
    <String, dynamic>{
      'title': instance.title,
      'branchName': instance.branchName,
      'worktreeName': instance.worktreeName,
    };
