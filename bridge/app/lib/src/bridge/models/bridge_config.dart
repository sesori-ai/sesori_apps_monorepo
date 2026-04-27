class BridgeConfig {
  final String relayURL;
  final String serverURL;
  final String? serverPassword;
  final String authBackendURL;

  /// How long a disconnected phone's SSE replay cursor stays valid.
  final Duration sseReplayWindow;
  final String version;
  final bool serverManaged;

  const BridgeConfig({
    required this.relayURL,
    required this.serverURL,
    required this.serverPassword,
    required this.authBackendURL,
    required this.sseReplayWindow,
    required this.version,
    required this.serverManaged,
  });
}
