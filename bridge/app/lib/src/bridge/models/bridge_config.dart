class BridgeConfig {
  final String relayURL;

  final String authBackendURL;

  /// How long a disconnected phone's SSE replay cursor stays valid.
  final Duration sseReplayWindow;

  /// Whether permission requests are approved at the bridge instead of being
  /// forwarded to clients.
  final bool yolo;

  const BridgeConfig({
    required this.relayURL,
    required this.authBackendURL,
    required this.sseReplayWindow,
    required this.yolo,
  });
}
