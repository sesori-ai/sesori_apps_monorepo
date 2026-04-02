import "package:freezed_annotation/freezed_annotation.dart";

part "opencode_config.freezed.dart";
part "opencode_config.g.dart";

/// Partial config response from `GET /config`.
/// Only the model fields are captured — the full response has many more.
@Freezed(fromJson: true, toJson: false)
sealed class OpenCodeConfig with _$OpenCodeConfig {
  const factory OpenCodeConfig({
    String? model,
    @JsonKey(name: "small_model") String? smallModel,
  }) = _OpenCodeConfig;

  factory OpenCodeConfig.fromJson(Map<String, dynamic> json) => _$OpenCodeConfigFromJson(json);
}
