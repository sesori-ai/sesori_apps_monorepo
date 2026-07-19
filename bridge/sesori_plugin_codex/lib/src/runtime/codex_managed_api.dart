import "package:sesori_plugin_interface/sesori_plugin_interface.dart"
    show BridgeDerivedProjectsPluginApi, BridgePluginApi, PluginWorkState;

/// The plugin-API object the [CodexPluginDescriptor] drives during `start()`.
///
/// It is the live [BridgeDerivedProjectsPluginApi] the bridge serves requests
/// through (codex has no native project concept, so the bridge derives its
/// projects from `listAllSessions`), plus an awaitable [initialize] so the
/// descriptor can complete cold-start (opening the `codex app-server` WebSocket
/// and performing the `initialize` handshake) — and surface a failure as a
/// degraded status — before returning. Keeping this as a small interface,
/// rather than the concrete `CodexPlugin`, lets the descriptor's API
/// construction be a test seam without forcing a real socket in unit tests.
abstract interface class CodexManagedApi implements BridgeDerivedProjectsPluginApi {
  Stream<PluginWorkState> get workState;
  PluginWorkState get currentWorkState;

  /// Opens the WebSocket transport, performs the `initialize` handshake, and
  /// starts pumping `codex app-server` notifications into [BridgePluginApi.events].
  ///
  /// Idempotent: repeated calls share a single in-flight cold-start. Throws on a
  /// cold-start failure so the descriptor can map it to a degraded status.
  Future<void> initialize();
}
