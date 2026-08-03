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
  const factory BridgeSettingUpdate.pullRequestRefreshInterval({
    @strictIntJsonConverter required int intervalSeconds,
  }) = PullRequestRefreshIntervalSettingUpdate;

  const factory BridgeSettingUpdate.unknown() = UnknownBridgeSettingUpdate;

  factory BridgeSettingUpdate.fromJson(Map<String, dynamic> json) => _$BridgeSettingUpdateFromJson(json);
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
  const factory BridgeSettingUpdateRejection.pullRequestRefreshIntervalOutOfRange({
    @strictIntJsonConverter required int minimumIntervalSeconds,
    @strictIntJsonConverter required int maximumIntervalSeconds,
  }) = PullRequestRefreshIntervalOutOfRangeSettingUpdateRejection;

  const factory BridgeSettingUpdateRejection.unknown() = UnknownBridgeSettingUpdateRejection;

  factory BridgeSettingUpdateRejection.fromJson(Map<String, dynamic> json) =>
      _$BridgeSettingUpdateRejectionFromJson(json);
}
