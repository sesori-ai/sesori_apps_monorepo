class BridgeConfig {
  final String relayURL;

  /// The active plugin's endpoint, from `BridgePlugin.describe()` — purely
  /// informational (the `Target:` startup log). All plugin traffic flows
  /// through the injected `BridgePluginApi`, never through this value.
  final String pluginEndpoint;

  final String authBackendURL;

  /// How long a disconnected phone's SSE replay cursor stays valid.
  final Duration sseReplayWindow;

  /// Whether permission requests are approved at the bridge instead of being
  /// forwarded to clients.
  final bool yolo;

  const BridgeConfig({
    required this.relayURL,
    required this.pluginEndpoint,
    required this.authBackendURL,
    required this.sseReplayWindow,
    required this.yolo,
  });
}
