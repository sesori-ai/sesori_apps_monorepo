// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'plugin_file_diff.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_PluginFileDiff _$PluginFileDiffFromJson(Map json) => _PluginFileDiff(
  file: json['file'] as String,
  before: json['before'] as String,
  after: json['after'] as String,
  additions: (json['additions'] as num).toInt(),
  deletions: (json['deletions'] as num).toInt(),
  status: json['status'] as String?,
);

Map<String, dynamic> _$PluginFileDiffToJson(_PluginFileDiff instance) =>
    <String, dynamic>{
      'file': instance.file,
      'before': instance.before,
      'after': instance.after,
      'additions': instance.additions,
      'deletions': instance.deletions,
      'status': instance.status,
    };
