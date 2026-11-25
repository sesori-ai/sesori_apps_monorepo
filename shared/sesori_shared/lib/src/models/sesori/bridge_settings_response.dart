import "package:freezed_annotation/freezed_annotation.dart";

import "bridge_release_track.dart";
import "bridge_tool_group_setting.dart";
import "pull_request_refresh_settings.dart";
import "yolo_settings.dart";

part "bridge_settings_response.freezed.dart";
part "bridge_settings_response.g.dart";

@Freezed(fromJson: true, toJson: true)
sealed class BridgeSettingsResponse with _$BridgeSettingsResponse {
  const factory({
    // COMPATIBILITY 2026-10-25 (v1.10.0): Apps older than v1.10.1 require this interval, which no longer has any
    // effect, so bridges still send it; current apps ignore it and accept its absence. Remove once public apps older
    // than v1.10.1 are unsupported.
    required PullRequestRefreshSettingsResponse? pullRequestRefresh,
    required YoloSettingsResponse yolo,
    // COMPATIBILITY 2026-09-03 (v1.8.3): Public v1.8.2 bridges omit this setting; remove null handling
    // once those bridges are no longer supported.
    required bool? warmUpPluginsOnSessionOpen,

    /// The master switch for Sesori's tools: while it is off, sessions get
    /// none of [toolGroups], whatever their own switches say.
    // COMPATIBILITY 2026-11-25 (v1.16.0): v1.15.0 bridges omit the master switch along with toolGroups, so its state
    // is unknown, and the app hides the Agent tools section for them. Remove null handling and require a bool once
    // the minimum supported bridge always sends it.
    required bool? agentToolsEnabled,

    /// The bridge's Sesori tool groups, in the order it serves them. A new
    /// session or resume picks up a change.
    // COMPATIBILITY 2026-11-24 (v1.16.0): Bridges before tool groups omit this list, and the app hides the section
    // when it is empty. Remove @Default and require the field once the minimum supported bridge always sends it.
    @Default(<BridgeToolGroupSetting>[]) List<BridgeToolGroupSetting> toolGroups,

    /// The release channel the bridge's auto-updater follows, or null for a
    /// bridge that does not update itself (one run by the desktop app, an npm
    /// payload, a development build, or updates turned off), which leaves the
    /// setting out.
    // COMPATIBILITY 2026-11-25 (v1.16.0): v1.15.0 bridges omit the track even when they update themselves, so the app
    // hides the setting for them too. Null keeps its meaning for bridges that do not update themselves; drop this note
    // once the minimum supported bridge sends the track.
    @JsonKey(unknownEnumValue: BridgeReleaseTrack.unknown) required BridgeReleaseTrack? releaseTrack,

    /// Whether the bridge keeps its computer from going to sleep while it runs.
    // COMPATIBILITY 2026-11-25 (v1.16.0): v1.15.0 bridges omit this setting, and the app shows no row for them. Remove
    // null handling and require a bool once the minimum supported bridge always sends it.
    required bool? preventSleep,
  }) = _BridgeSettingsResponse;

  factory fromJson(Map<String, dynamic> json) => _$BridgeSettingsResponseFromJson(json);
}
