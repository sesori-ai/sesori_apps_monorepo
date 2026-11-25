// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pull_request_monitor_config.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_PullRequestMonitorConfig _$PullRequestMonitorConfigFromJson(Map json) => _PullRequestMonitorConfig(
  autoMerge: json['autoMerge'] as bool,
  repositoryAutoMerge: Map<String, bool>.from(
    json['repositoryAutoMerge'] as Map,
  ),
  quietMinutes: (json['quietMinutes'] as num).toInt(),
  ciWaitMinutes: (json['ciWaitMinutes'] as num).toInt(),
  idleReminderMinutes: (json['idleReminderMinutes'] as num?)?.toInt(),
);

Map<String, dynamic> _$PullRequestMonitorConfigToJson(
  _PullRequestMonitorConfig instance,
) => <String, dynamic>{
  'autoMerge': instance.autoMerge,
  'repositoryAutoMerge': instance.repositoryAutoMerge,
  'quietMinutes': instance.quietMinutes,
  'ciWaitMinutes': instance.ciWaitMinutes,
  'idleReminderMinutes': ?instance.idleReminderMinutes,
};
