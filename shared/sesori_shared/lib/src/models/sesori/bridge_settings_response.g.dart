// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'bridge_settings_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_BridgeSettingsResponse _$BridgeSettingsResponseFromJson(Map json) =>
    _BridgeSettingsResponse(
      pullRequestRefresh: PullRequestRefreshSettingsResponse.fromJson(
        Map<String, dynamic>.from(json['pullRequestRefresh'] as Map),
      ),
      yolo: YoloSettingsResponse.fromJson(
        Map<String, dynamic>.from(json['yolo'] as Map),
      ),
    );

Map<String, dynamic> _$BridgeSettingsResponseToJson(
  _BridgeSettingsResponse instance,
) => <String, dynamic>{
  'pullRequestRefresh': instance.pullRequestRefresh.toJson(),
  'yolo': instance.yolo.toJson(),
};
