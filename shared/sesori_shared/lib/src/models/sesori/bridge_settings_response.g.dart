// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'bridge_settings_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_BridgeSettingsResponse _$BridgeSettingsResponseFromJson(Map json) =>
    _BridgeSettingsResponse(
      pullRequestRefresh: json['pullRequestRefresh'] == null
          ? null
          : PullRequestRefreshSettingsResponse.fromJson(
              Map<String, dynamic>.from(json['pullRequestRefresh'] as Map),
            ),
      yolo: YoloSettingsResponse.fromJson(
        Map<String, dynamic>.from(json['yolo'] as Map),
      ),
      warmUpPluginsOnSessionOpen: json['warmUpPluginsOnSessionOpen'] as bool?,
      agentToolsEnabled: json['agentToolsEnabled'] as bool?,
      toolGroups:
          (json['toolGroups'] as List<dynamic>?)
              ?.map(
                (e) => BridgeToolGroupSetting.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ),
              )
              .toList() ??
          const <BridgeToolGroupSetting>[],
      releaseTrack: $enumDecodeNullable(
        _$BridgeReleaseTrackEnumMap,
        json['releaseTrack'],
        unknownValue: BridgeReleaseTrack.unknown,
      ),
      preventSleep: $enumDecodeNullable(
        _$SleepPreventionStatusEnumMap,
        json['preventSleep'],
        unknownValue: SleepPreventionStatus.unknown,
      ),
    );

Map<String, dynamic> _$BridgeSettingsResponseToJson(
  _BridgeSettingsResponse instance,
) => <String, dynamic>{
  'pullRequestRefresh': ?instance.pullRequestRefresh?.toJson(),
  'yolo': instance.yolo.toJson(),
  'warmUpPluginsOnSessionOpen': ?instance.warmUpPluginsOnSessionOpen,
  'agentToolsEnabled': ?instance.agentToolsEnabled,
  'toolGroups': instance.toolGroups.map((e) => e.toJson()).toList(),
  'releaseTrack': ?_$BridgeReleaseTrackEnumMap[instance.releaseTrack],
  'preventSleep': ?_$SleepPreventionStatusEnumMap[instance.preventSleep],
};

const _$BridgeReleaseTrackEnumMap = {
  BridgeReleaseTrack.stable: 'stable',
  BridgeReleaseTrack.internal: 'internal',
  BridgeReleaseTrack.unknown: 'unknown',
};

const _$SleepPreventionStatusEnumMap = {
  SleepPreventionStatus.off: 'off',
  SleepPreventionStatus.awake: 'awake',
  SleepPreventionStatus.failed: 'failed',
  SleepPreventionStatus.unknown: 'unknown',
};
