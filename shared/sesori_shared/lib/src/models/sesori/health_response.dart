import "package:freezed_annotation/freezed_annotation.dart";

part "health_response.freezed.dart";

part "health_response.g.dart";

/// How the bridge was installed, which decides how the user updates it.
enum BridgeKind() {
  /// The standalone command-line bridge, updated with `sesori-bridge update`.
  @JsonValue("cli")
  cli,

  /// The bridge bundled with and supervised by Sesori Desktop, updated by the
  /// desktop app's own updater.
  @JsonValue("desktop")
  desktop,
}

@Freezed(fromJson: true, toJson: true)
sealed class HealthResponse with _$HealthResponse {
  const factory({
    required bool healthy,
    required String version,
    // Whether the bridge detected degraded host filesystem access at startup
    // (e.g. macOS Full Disk Access not granted), so the phone can proactively
    // warn the user.
    required bool filesystemAccessDegraded,
    // COMPATIBILITY 2026-10-06 (v1.9.1): bridges released before this field
    // omit it, and every one of them is a command-line bridge because Sesori
    // Desktop had not shipped yet, so absence honestly means cli. An unknown
    // value from a newer bridge also falls back to cli. Remove @Default and
    // require the field once every supported bridge sends it.
    @JsonKey(unknownEnumValue: BridgeKind.cli) @Default(BridgeKind.cli) BridgeKind bridgeKind,
  }) = _HealthResponse;

  factory fromJson(Map<String, dynamic> json) => _$HealthResponseFromJson(json);
}
