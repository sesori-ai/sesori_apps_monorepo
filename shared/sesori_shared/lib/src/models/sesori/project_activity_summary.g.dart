// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'project_activity_summary.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ProjectActivitySummary _$ProjectActivitySummaryFromJson(Map json) =>
    _ProjectActivitySummary(
      worktree: json['worktree'] as String,
      activeSessions: (json['activeSessions'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$ProjectActivitySummaryToJson(
  _ProjectActivitySummary instance,
) => <String, dynamic>{
  'worktree': instance.worktree,
  'activeSessions': instance.activeSessions,
};
