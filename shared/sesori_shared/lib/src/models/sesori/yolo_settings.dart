import "package:freezed_annotation/freezed_annotation.dart";

part "yolo_settings.freezed.dart";
part "yolo_settings.g.dart";

@Freezed(fromJson: true, toJson: true)
sealed class YoloSettingsResponse with _$YoloSettingsResponse {
  const factory({required bool enabled}) = _YoloSettingsResponse;

  factory fromJson(Map<String, dynamic> json) => _$YoloSettingsResponseFromJson(json);
}
