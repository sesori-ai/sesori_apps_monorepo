import "package:freezed_annotation/freezed_annotation.dart";

part "bridge_tool_group_setting.freezed.dart";
part "bridge_tool_group_setting.g.dart";

/// One of the bridge's Sesori tool groups, with its toggle state. The bridge
/// sends the label texts, so a new group needs no app release.
@Freezed(fromJson: true, toJson: true)
sealed class BridgeToolGroupSetting with _$BridgeToolGroupSetting {
  const factory({
    required String id,
    required String title,
    required String summary,
    required bool enabled,
  }) = _BridgeToolGroupSetting;

  factory fromJson(Map<String, dynamic> json) => _$BridgeToolGroupSettingFromJson(json);
}
