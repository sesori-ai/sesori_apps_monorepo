// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'bridge_setting_update.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PullRequestRefreshIntervalSettingUpdate
_$PullRequestRefreshIntervalSettingUpdateFromJson(Map json) =>
    PullRequestRefreshIntervalSettingUpdate(
      intervalSeconds: _strictIntFromJson(json['intervalSeconds']),
      $type: json['type'] as String?,
    );

Map<String, dynamic> _$PullRequestRefreshIntervalSettingUpdateToJson(
  PullRequestRefreshIntervalSettingUpdate instance,
) => <String, dynamic>{
  'intervalSeconds': instance.intervalSeconds,
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
  minimumIntervalSeconds: _strictIntFromJson(json['minimumIntervalSeconds']),
  maximumIntervalSeconds: _strictIntFromJson(json['maximumIntervalSeconds']),
  $type: json['type'] as String?,
);

Map<String, dynamic>
_$PullRequestRefreshIntervalOutOfRangeSettingUpdateRejectionToJson(
  PullRequestRefreshIntervalOutOfRangeSettingUpdateRejection instance,
) => <String, dynamic>{
  'minimumIntervalSeconds': instance.minimumIntervalSeconds,
  'maximumIntervalSeconds': instance.maximumIntervalSeconds,
  'type': instance.$type,
};

UnknownBridgeSettingUpdateRejection
_$UnknownBridgeSettingUpdateRejectionFromJson(Map json) =>
    UnknownBridgeSettingUpdateRejection($type: json['type'] as String?);

Map<String, dynamic> _$UnknownBridgeSettingUpdateRejectionToJson(
  UnknownBridgeSettingUpdateRejection instance,
) => <String, dynamic>{'type': instance.$type};
