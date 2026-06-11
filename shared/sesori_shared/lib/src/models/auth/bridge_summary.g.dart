// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'bridge_summary.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_BridgeSummary _$BridgeSummaryFromJson(Map json) => _BridgeSummary(
  id: json['id'] as String,
  name: json['name'] as String,
  platform: json['platform'] as String,
  addedAt: DateTime.parse(json['addedAt'] as String),
  lastSeenAt: json['lastSeenAt'] == null
      ? null
      : DateTime.parse(json['lastSeenAt'] as String),
);

Map<String, dynamic> _$BridgeSummaryToJson(_BridgeSummary instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'platform': instance.platform,
      'addedAt': instance.addedAt.toIso8601String(),
      'lastSeenAt': instance.lastSeenAt?.toIso8601String(),
    };
