// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'bridge_summary.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_BridgeSummary _$BridgeSummaryFromJson(Map json) => _BridgeSummary(
  id: json['id'] as String,
  name: json['name'] as String,
  platform: $enumDecode(
    _$BridgePlatformEnumMap,
    json['platform'],
    unknownValue: BridgePlatform.unknown,
  ),
  status: $enumDecode(_$BridgeRegistrationStatusEnumMap, json['status']),
  addedAt: DateTime.parse(json['addedAt'] as String),
  lastSeenAt: json['lastSeenAt'] == null
      ? null
      : DateTime.parse(json['lastSeenAt'] as String),
);

Map<String, dynamic> _$BridgeSummaryToJson(_BridgeSummary instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'platform': _$BridgePlatformEnumMap[instance.platform]!,
      'status': _$BridgeRegistrationStatusEnumMap[instance.status]!,
      'addedAt': instance.addedAt.toIso8601String(),
      'lastSeenAt': ?instance.lastSeenAt?.toIso8601String(),
    };

const _$BridgePlatformEnumMap = {
  BridgePlatform.macos: 'macos',
  BridgePlatform.windows: 'windows',
  BridgePlatform.linux: 'linux',
  BridgePlatform.unknown: 'unknown',
};

const _$BridgeRegistrationStatusEnumMap = {
  BridgeRegistrationStatus.active: 'active',
  BridgeRegistrationStatus.inactive: 'inactive',
};
