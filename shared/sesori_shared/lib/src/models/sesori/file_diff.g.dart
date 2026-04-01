// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'file_diff.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

FileDiffContent _$FileDiffContentFromJson(Map json) => FileDiffContent(
  file: json['file'] as String,
  before: json['before'] as String,
  after: json['after'] as String,
  additions: (json['additions'] as num).toInt(),
  deletions: (json['deletions'] as num).toInt(),
  status: $enumDecodeNullable(_$FileDiffStatusEnumMap, json['status']),
  $type: json['runtimeType'] as String?,
);

Map<String, dynamic> _$FileDiffContentToJson(FileDiffContent instance) =>
    <String, dynamic>{
      'file': instance.file,
      'before': instance.before,
      'after': instance.after,
      'additions': instance.additions,
      'deletions': instance.deletions,
      'status': _$FileDiffStatusEnumMap[instance.status],
      'runtimeType': instance.$type,
    };

const _$FileDiffStatusEnumMap = {
  FileDiffStatus.added: 'added',
  FileDiffStatus.deleted: 'deleted',
  FileDiffStatus.modified: 'modified',
};

FileDiffSkipped _$FileDiffSkippedFromJson(Map json) => FileDiffSkipped(
  file: json['file'] as String,
  reason: $enumDecode(_$FileDiffSkipReasonEnumMap, json['reason']),
  status: $enumDecodeNullable(_$FileDiffStatusEnumMap, json['status']),
  $type: json['runtimeType'] as String?,
);

Map<String, dynamic> _$FileDiffSkippedToJson(FileDiffSkipped instance) =>
    <String, dynamic>{
      'file': instance.file,
      'reason': _$FileDiffSkipReasonEnumMap[instance.reason]!,
      'status': _$FileDiffStatusEnumMap[instance.status],
      'runtimeType': instance.$type,
    };

const _$FileDiffSkipReasonEnumMap = {
  FileDiffSkipReason.binary: 'binary',
  FileDiffSkipReason.tooLarge: 'tooLarge',
  FileDiffSkipReason.readError: 'readError',
};
