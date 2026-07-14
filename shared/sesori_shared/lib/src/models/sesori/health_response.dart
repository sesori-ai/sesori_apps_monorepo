import "package:freezed_annotation/freezed_annotation.dart";

part "health_response.freezed.dart";

part "health_response.g.dart";

@Freezed(fromJson: true, toJson: true)
sealed class HealthResponse with _$HealthResponse {
  const factory HealthResponse({
    required bool healthy,
    required String version,
    // Whether the bridge detected degraded host filesystem access at startup
    // (e.g. macOS Full Disk Access not granted), so the phone can proactively
    // warn the user. Nullable for backward compatibility: an older bridge that
    // never sends it decodes to null and is treated as "not degraded".
    // COMPATIBILITY 2026-06-27 (v1.2.0): Old bridges omit filesystem-access state. Make this non-null and remove client null fallbacks once those bridges are unsupported.
    required bool? filesystemAccessDegraded,
  }) = _HealthResponse;

  factory HealthResponse.fromJson(Map<String, dynamic> json) => _$HealthResponseFromJson(json);
}
