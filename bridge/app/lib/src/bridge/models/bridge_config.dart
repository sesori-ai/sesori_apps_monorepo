class const BridgeConfig({
  required final String relayURL,
  required final String authBackendURL,

  /// How long a disconnected phone's SSE replay cursor stays valid.
  required final Duration sseReplayWindow,

  /// Whether permission requests are approved at the bridge instead of being
  /// forwarded to clients.
  required final bool yolo,
});
