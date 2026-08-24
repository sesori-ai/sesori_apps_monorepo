import "package:freezed_annotation/freezed_annotation.dart";

part "health_response.freezed.dart";

part "health_response.g.dart";

@Freezed(fromJson: true, toJson: true)
sealed class HealthResponse with _$HealthResponse {
  const factory({
    required bool healthy,
    required String version,
    // Whether the bridge detected degraded host filesystem access at startup
    // (e.g. macOS Full Disk Access not granted), so the phone can proactively
    // warn the user.
    required bool filesystemAccessDegraded,
  }) = _HealthResponse;

  factory fromJson(Map<String, dynamic> json) => _$HealthResponseFromJson(json);
}
