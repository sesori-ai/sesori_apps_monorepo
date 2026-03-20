// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'project_activity_summary.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ProjectActivitySummary _$ProjectActivitySummaryFromJson(Map json) =>
    _ProjectActivitySummary(
      id: json['id'] as String,
      activeSessions: (json['activeSessions'] as num?)?.toInt() ?? 0,
      activeSessionIds:
          (json['activeSessionIds'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
    );

Map<String, dynamic> _$ProjectActivitySummaryToJson(
  _ProjectActivitySummary instance,
) => <String, dynamic>{
  'id': instance.id,
  'activeSessions': instance.activeSessions,
  'activeSessionIds': instance.activeSessionIds,
};
