// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'stored_pull_request_watch.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_StoredPullRequestWatch _$StoredPullRequestWatchFromJson(Map json) => _StoredPullRequestWatch(
  owner: json['owner'] as String,
  repo: json['repo'] as String,
  number: (json['number'] as num).toInt(),
  title: json['title'] as String,
  autoMerge: json['autoMerge'] as bool,
  baseline: PullRequestBaseline.fromJson(
    Map<String, dynamic>.from(json['baseline'] as Map),
  ),
  lastReportAt: DateTime.parse(json['lastReportAt'] as String),
);

Map<String, dynamic> _$StoredPullRequestWatchToJson(
  _StoredPullRequestWatch instance,
) => <String, dynamic>{
  'owner': instance.owner,
  'repo': instance.repo,
  'number': instance.number,
  'title': instance.title,
  'autoMerge': instance.autoMerge,
  'baseline': instance.baseline.toJson(),
  'lastReportAt': instance.lastReportAt.toIso8601String(),
};
