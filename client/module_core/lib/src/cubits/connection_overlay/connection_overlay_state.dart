import "package:freezed_annotation/freezed_annotation.dart";

part "connection_overlay_state.freezed.dart";

/// What the app-wide connection banner should display, derived from the
/// connection status and whether the account has a registered bridge.
///
/// The bridge-offline distinction is the reason this is a view-state rather than
/// the raw `ConnectionStatus`: a `ConnectionBridgeOffline` park only warrants the
/// [bridgeOffline] banner when the account actually has a registered bridge. An
/// account that has never registered one parks offline as a normal part of
/// onboarding and must show nothing ([hidden]).
@Freezed()
sealed class ConnectionOverlayState with _$ConnectionOverlayState {
  /// Nothing shown — connected, pre-connection, or a bridge-offline park for an
  /// account that has never registered a bridge (its onboarding owns that
  /// messaging).
  const factory ConnectionOverlayState.hidden() = ConnectionOverlayHidden;

  /// A subtle reconnecting indicator: the relay dropped and is auto-reconnecting.
  const factory ConnectionOverlayState.reconnecting() = ConnectionOverlayReconnecting;

  /// The blocking "connection lost" card with Reconnect / Disconnect actions.
  const factory ConnectionOverlayState.connectionLost() = ConnectionOverlayConnectionLost;

  /// The non-blocking bridge-offline banner — shown only when the account has a
  /// registered bridge, so an offline bridge is worth flagging.
  const factory ConnectionOverlayState.bridgeOffline() = ConnectionOverlayBridgeOffline;
}
