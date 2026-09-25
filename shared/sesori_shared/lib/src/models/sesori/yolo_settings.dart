import "package:freezed_annotation/freezed_annotation.dart";

part "yolo_settings.freezed.dart";
part "yolo_settings.g.dart";

@Freezed(fromJson: true, toJson: true)
sealed class YoloSettingsResponse with _$YoloSettingsResponse {
  const factory({
    /// The bridge-wide default. A session's `approvalOverride` wins over it.
    required bool enabled,

    /// Whether the bridge stores a per-session approval override and accepts
    /// `PATCH /session/approval-override`.
    // COMPATIBILITY 2026-09-25 (v1.9.1): Bridges before per-session approval omit this and cannot store an override, so the app offers no per-session choice. Remove @Default and require the field once the minimum supported bridge always sends it.
    @Default(false) bool supportsSessionOverride,
  }) = _YoloSettingsResponse;

  factory fromJson(Map<String, dynamic> json) => _$YoloSettingsResponseFromJson(json);
}
