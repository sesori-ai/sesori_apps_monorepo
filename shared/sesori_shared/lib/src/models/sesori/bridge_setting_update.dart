import "package:freezed_annotation/freezed_annotation.dart";

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
    @JsonKey(fromJson: _strictIntFromJson) required int intervalSeconds,
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
    @JsonKey(fromJson: _strictIntFromJson) required int minimumIntervalSeconds,
    @JsonKey(fromJson: _strictIntFromJson) required int maximumIntervalSeconds,
  }) = PullRequestRefreshIntervalOutOfRangeSettingUpdateRejection;

  const factory BridgeSettingUpdateRejection.unknown() = UnknownBridgeSettingUpdateRejection;

  factory BridgeSettingUpdateRejection.fromJson(Map<String, dynamic> json) =>
      _$BridgeSettingUpdateRejectionFromJson(json);
}

// ignore: no_slop_linter/prefer_specific_type, JSON converter input must validate the raw value
int _strictIntFromJson(Object? value) {
  if (value is int) return value;
  throw const FormatException("Expected an integer");
}
