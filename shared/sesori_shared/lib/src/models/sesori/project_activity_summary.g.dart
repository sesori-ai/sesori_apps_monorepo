// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'project_activity_summary.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ProjectActivitySummary _$ProjectActivitySummaryFromJson(Map json) =>
    _ProjectActivitySummary(
      id: json['id'] as String,
      activeSessions: (json['activeSessions'] as List<dynamic>)
          .map(
            (e) => ActiveSession.fromJson(Map<String, dynamic>.from(e as Map)),
          )
          .toList(),
    );

Map<String, dynamic> _$ProjectActivitySummaryToJson(
  _ProjectActivitySummary instance,
) => <String, dynamic>{
  'id': instance.id,
  'activeSessions': instance.activeSessions.map((e) => e.toJson()).toList(),
};
