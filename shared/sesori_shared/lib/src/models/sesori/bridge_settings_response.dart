import "package:freezed_annotation/freezed_annotation.dart";

import "pull_request_refresh_settings.dart";
import "yolo_settings.dart";

part "bridge_settings_response.freezed.dart";
part "bridge_settings_response.g.dart";

@Freezed(fromJson: true, toJson: true)
sealed class BridgeSettingsResponse with _$BridgeSettingsResponse {
  const factory BridgeSettingsResponse({
    required PullRequestRefreshSettingsResponse pullRequestRefresh,
    required YoloSettingsResponse yolo,
  }) = _BridgeSettingsResponse;

  factory BridgeSettingsResponse.fromJson(Map<String, dynamic> json) => _$BridgeSettingsResponseFromJson(json);
}
