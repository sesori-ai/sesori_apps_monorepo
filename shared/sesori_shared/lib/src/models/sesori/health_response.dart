import "package:freezed_annotation/freezed_annotation.dart";

part "health_response.freezed.dart";

part "health_response.g.dart";

@Freezed(fromJson: true, toJson: true)
sealed class HealthResponse with _$HealthResponse {
  const factory HealthResponse({
    required bool healthy,
    required String version,
  }) = _HealthResponse;

  factory HealthResponse.fromJson(Map<String, dynamic> json) => _$HealthResponseFromJson(json);
}
