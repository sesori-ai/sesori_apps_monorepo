import "package:freezed_annotation/freezed_annotation.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../server_connection_config.dart";

part "connection_status.freezed.dart";

@Freezed()
sealed class ConnectionStatus with _$ConnectionStatus {
  /// No config, not connected at all.
  const factory ConnectionStatus.disconnected() = ConnectionDisconnected;

  /// SSE stream alive, heartbeats flowing.
  const factory ConnectionStatus.connected({
    required ServerConnectionConfig config,
    required HealthResponse health,
  }) = ConnectionConnected;

  /// A relay connection attempt is in progress. Automatic retries use bounded
  /// exponential backoff; manual and lifecycle attempts may be immediate.
  /// UI stays as-is — no overlay yet.
  const factory ConnectionStatus.reconnecting({
    required ServerConnectionConfig config,
  }) = ConnectionReconnecting;

  /// Automatic reconnect is paused or stopped (for example, while the app is
  /// backgrounded, authentication is missing, or the relay close is terminal).
  /// Overlay shows with Reconnect / Disconnect actions.
  const factory ConnectionStatus.connectionLost({
    required ServerConnectionConfig config,
  }) = ConnectionLost;

  /// Relay connection is active but the bridge (desktop process) is offline.
  /// Non-blocking — user can still view the app but cannot interact with sessions.
  /// Transitions back to [ConnectionConnected] when the bridge comes back online.
  const factory ConnectionStatus.bridgeOffline({
    required ServerConnectionConfig config,
    required HealthResponse health,
  }) = ConnectionBridgeOffline;
}
