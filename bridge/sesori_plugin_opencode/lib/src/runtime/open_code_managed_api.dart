import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show NativeProjectsPluginApi;

/// The plugin-API object the [OpenCodePluginDescriptor] drives during `start()`.
///
/// It is the live [NativeProjectsPluginApi] the bridge serves requests through
/// (OpenCode's backend owns its project list natively), plus an awaitable
/// [initialize] so the descriptor can complete cold-start (and surface
/// a failure as a degraded status) before returning. Keeping this as a small
/// interface — rather than the concrete `OpenCodePlugin` — lets the descriptor's
/// API construction be a test seam without forcing real HTTP/SSE in unit tests.
abstract interface class OpenCodeManagedApi implements NativeProjectsPluginApi {
  /// Hydrates the session tracker from the server and starts the SSE stream.
  ///
  /// Idempotent: repeated calls share a single in-flight cold-start. Rethrows a
  /// cold-start failure (after the SSE stream has been started so it can still
  /// recover) so the descriptor can map it to a degraded status.
  Future<void> initialize();
}
