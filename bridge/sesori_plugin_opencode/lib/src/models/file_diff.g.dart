// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'file_diff.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_FileDiff _$FileDiffFromJson(Map json) => _FileDiff(
  file: json['file'] as String,
  before: json['before'] as String,
  after: json['after'] as String,
  additions: (json['additions'] as num).toInt(),
  deletions: (json['deletions'] as num).toInt(),
  status: $enumDecodeNullable(_$FileDiffStatusEnumMap, json['status']),
);

Map<String, dynamic> _$FileDiffToJson(_FileDiff instance) => <String, dynamic>{
  'file': instance.file,
  'before': instance.before,
  'after': instance.after,
  'additions': instance.additions,
  'deletions': instance.deletions,
  'status': _$FileDiffStatusEnumMap[instance.status],
};

const _$FileDiffStatusEnumMap = {
  FileDiffStatus.added: 'added',
  FileDiffStatus.deleted: 'deleted',
  FileDiffStatus.modified: 'modified',
};
