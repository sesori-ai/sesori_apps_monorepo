import "package:freezed_annotation/freezed_annotation.dart";

part "open_code_probe_response.freezed.dart";
part "open_code_probe_response.g.dart";

/// Minimal shared shape of the v1 health and v2 info responses.
/// Full API clients own the remaining protocol-specific fields.
@Freezed(toJson: false)
sealed class OpenCodeProbeResponse with _$OpenCodeProbeResponse {
  // ignore: invalid_annotation_target, Freezed forwards this to the generated class.
  @JsonSerializable(checked: true)
  const factory({required String? version}) = _OpenCodeProbeResponse;

  factory fromJson(Map<String, dynamic> json) => _$OpenCodeProbeResponseFromJson(json);
}
