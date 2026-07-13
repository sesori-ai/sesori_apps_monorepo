import "package:freezed_annotation/freezed_annotation.dart";
import "package:sesori_shared/sesori_shared.dart";

part "bridge_control_status.freezed.dart";

/// Snapshot of the supervised bridge as seen over the control channel.
///
/// Reuses the shared control-protocol enums directly (ADR A4) so a newer
/// helper's unknown values flow through untouched. Named `BridgeControlStatus`
/// because `sesori_dart_core` already exports a relay-side `BridgeStatus`.
@Freezed()
sealed class BridgeControlStatus with _$BridgeControlStatus {
  const factory BridgeControlStatus({
    /// Whether a helper is currently connected to the GUI's control channel.
    required bool helperOnline,
    required ControlRelayConnectionState relay,
    required ControlPluginHealthState plugin,
    required int activeSessionCount,

    /// Readable copy of the helper's bridge id (from the `registered` event).
    /// Retained across helper disconnects — the offline-unregister fallback
    /// needs it exactly when the helper is gone.
    required String? bridgeId,
  }) = _BridgeControlStatus;

  /// Baseline before any helper has connected: bridge off, nothing known.
  static const BridgeControlStatus offline = BridgeControlStatus(
    helperOnline: false,
    relay: ControlRelayConnectionState.disconnected,
    plugin: ControlPluginHealthState.unknown,
    activeSessionCount: 0,
    bridgeId: null,
  );
}
