import "package:freezed_annotation/freezed_annotation.dart";

import "pull_request_refresh_settings.dart";
import "yolo_settings.dart";

part "bridge_settings_response.freezed.dart";
part "bridge_settings_response.g.dart";

@Freezed(fromJson: true, toJson: true)
sealed class BridgeSettingsResponse with _$BridgeSettingsResponse {
  const factory({
    // COMPATIBILITY 2026-10-25 (v1.10.0): Apps older than v1.10.0 require this interval, which no longer has any
    // effect, so bridges still send it; current apps ignore it and accept its absence. Remove once public apps older
    // than v1.10.0 are unsupported.
    required PullRequestRefreshSettingsResponse? pullRequestRefresh,
    required YoloSettingsResponse yolo,
    // COMPATIBILITY 2026-09-03 (v1.8.3): Public v1.8.2 bridges omit this setting; remove null handling
    // once those bridges are no longer supported.
    required bool? warmUpPluginsOnSessionOpen,
  }) = _BridgeSettingsResponse;

  factory fromJson(Map<String, dynamic> json) => _$BridgeSettingsResponseFromJson(json);
}
