import "package:sesori_plugin_interface/sesori_plugin_interface.dart"
    show
        BridgeHostInfo,
        HostJsonStore,
        HostPortService,
        HostProcessService,
        PluginConfig,
        PluginHost,
        ServerClock,
        StartAbortSignal;

import "../api/runtime_file_api.dart";

/// The bridge's production [PluginHost].
///
/// The constructor is pure wiring (tests may inject fakes per service);
/// [create] assembles the production services from the bridge's existing
/// seams and creates [stateDirectory] — the contract promises it exists
/// before the plugin's `start()` runs.
///
/// [create] builds a fresh [RuntimeFileApi] over [stateDirectory]. When the
/// bridge already holds a [RuntimeFileApi] over that directory (OpenCode's
/// `<cacheDir>/runtime`), wire through the plain constructor with a store
/// over the shared instance instead — `RuntimeFileApi.updateFile`'s mutual
/// exclusion is only guaranteed within one instance per directory.
class BridgePluginHostImpl({
  @override required final PluginConfig config,
  @override required final String stateDirectory,
  @override required final Map<String, String> environment,
  @override required final ServerClock clock,
  @override required final StartAbortSignal startAborted,
  @override required final BridgeHostInfo bridge,
  @override required final HostProcessService processes,
  @override required final HostPortService ports,
  @override required final HostJsonStore store,
  required final Duration? Function() _resolveIdleTimeout,
}) implements PluginHost {
  /// Live view over the bridge's runtime-mutable per-plugin idle timeout, so
  /// a settings change reaches the plugin without a restart.
  @override
  Duration? get pluginIdleTimeout => _resolveIdleTimeout();

  /// Set by the bridge runner from `ensureRuntime`'s [ProvisionReady] result,
  /// after the host is built and before `start()` runs; `null` when the plugin
  /// did no provisioning or it failed.
  @override
  String? provisionedRuntimePath;
}
