import "package:freezed_annotation/freezed_annotation.dart";

import "../../converters/strict_int_json_converter.dart";

part "bridge_setting_update.freezed.dart";
part "bridge_setting_update.g.dart";

@Freezed(
  unionKey: "type",
  fallbackUnion: "unknown",
  fromJson: true,
  toJson: true,
  copyWith: false,
)
sealed class BridgeSettingUpdate with _$BridgeSettingUpdate {
  @FreezedUnionValue("pullRequestRefreshInterval")
  const factory pullRequestRefreshInterval({
    @strictIntJsonConverter required int intervalSeconds,
  }) = PullRequestRefreshIntervalSettingUpdate;

  @FreezedUnionValue("yolo")
  const factory yolo({required bool enabled}) = YoloSettingUpdate;

  @FreezedUnionValue("warmUpPluginsOnSessionOpen")
  const factory warmUpPluginsOnSessionOpen({required bool enabled}) = WarmUpPluginsOnSessionOpenSettingUpdate;

  const factory unknown() = UnknownBridgeSettingUpdate;

  factory fromJson(Map<String, dynamic> json) => _$BridgeSettingUpdateFromJson(json);
}

@Freezed(
  unionKey: "type",
  fallbackUnion: "unknown",
  fromJson: true,
  toJson: true,
  copyWith: false,
)
sealed class BridgeSettingUpdateRejection with _$BridgeSettingUpdateRejection {
  @FreezedUnionValue("pullRequestRefreshIntervalOutOfRange")
  const factory pullRequestRefreshIntervalOutOfRange({
    @strictIntJsonConverter required int minimumIntervalSeconds,
    @strictIntJsonConverter required int maximumIntervalSeconds,
  }) = PullRequestRefreshIntervalOutOfRangeSettingUpdateRejection;

  const factory unknown() = UnknownBridgeSettingUpdateRejection;

  factory fromJson(Map<String, dynamic> json) => _$BridgeSettingUpdateRejectionFromJson(json);
}
