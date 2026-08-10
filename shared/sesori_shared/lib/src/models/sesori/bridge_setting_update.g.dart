// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'bridge_setting_update.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PullRequestRefreshIntervalSettingUpdate _$PullRequestRefreshIntervalSettingUpdateFromJson(Map json) =>
    PullRequestRefreshIntervalSettingUpdate(
      intervalSeconds: strictIntJsonConverter.fromJson(json['intervalSeconds']),
      $type: json['type'] as String?,
    );

Map<String, dynamic> _$PullRequestRefreshIntervalSettingUpdateToJson(
  PullRequestRefreshIntervalSettingUpdate instance,
) => <String, dynamic>{
  'intervalSeconds': ?strictIntJsonConverter.toJson(instance.intervalSeconds),
  'type': instance.$type,
};

YoloSettingUpdate _$YoloSettingUpdateFromJson(Map json) => YoloSettingUpdate(
  enabled: json['enabled'] as bool,
  $type: json['type'] as String?,
);

Map<String, dynamic> _$YoloSettingUpdateToJson(YoloSettingUpdate instance) => <String, dynamic>{
  'enabled': instance.enabled,
  'type': instance.$type,
};

UnknownBridgeSettingUpdate _$UnknownBridgeSettingUpdateFromJson(Map json) =>
    UnknownBridgeSettingUpdate($type: json['type'] as String?);

Map<String, dynamic> _$UnknownBridgeSettingUpdateToJson(
  UnknownBridgeSettingUpdate instance,
) => <String, dynamic>{'type': instance.$type};

PullRequestRefreshIntervalOutOfRangeSettingUpdateRejection
_$PullRequestRefreshIntervalOutOfRangeSettingUpdateRejectionFromJson(
  Map json,
) => PullRequestRefreshIntervalOutOfRangeSettingUpdateRejection(
  minimumIntervalSeconds: strictIntJsonConverter.fromJson(
    json['minimumIntervalSeconds'],
  ),
  maximumIntervalSeconds: strictIntJsonConverter.fromJson(
    json['maximumIntervalSeconds'],
  ),
  $type: json['type'] as String?,
);

Map<String, dynamic> _$PullRequestRefreshIntervalOutOfRangeSettingUpdateRejectionToJson(
  PullRequestRefreshIntervalOutOfRangeSettingUpdateRejection instance,
) => <String, dynamic>{
  'minimumIntervalSeconds': ?strictIntJsonConverter.toJson(
    instance.minimumIntervalSeconds,
  ),
  'maximumIntervalSeconds': ?strictIntJsonConverter.toJson(
    instance.maximumIntervalSeconds,
  ),
  'type': instance.$type,
};

UnknownBridgeSettingUpdateRejection _$UnknownBridgeSettingUpdateRejectionFromJson(Map json) =>
    UnknownBridgeSettingUpdateRejection($type: json['type'] as String?);

Map<String, dynamic> _$UnknownBridgeSettingUpdateRejectionToJson(
  UnknownBridgeSettingUpdateRejection instance,
) => <String, dynamic>{'type': instance.$type};
