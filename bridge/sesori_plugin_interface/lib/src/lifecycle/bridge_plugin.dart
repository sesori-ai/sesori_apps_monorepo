import "../bridge_plugin.dart";
import "plugin_diagnostics.dart";
import "plugin_status.dart";

/// A live plugin instance, as returned by `BridgePluginDescriptor.start`.
///
/// Pairs the request surface ([api]) with the lifecycle surface ([status],
/// [describe], [shutdown]). For simple plugins (direct CLI, remote server)
/// mix in `SteadyPluginLifecycle` and the lifecycle surface reduces to a few
/// lines.
abstract class BridgePlugin {
  /// The request surface the bridge routes traffic through.
  ///
  /// Must be the *same object* for the plugin's entire lifetime: the bridge
  /// publishes it in its operational plugin map. A plugin whose
  /// transport can be replaced (e.g. a restarted runtime) must put a stable
  /// facade here and swap the transport behind it.
  BridgePluginApi get api;

  /// Replay-latest lifecycle status: every listener immediately receives
  /// the current status, then live updates. Closes after `PluginStopped`.
  ///
  /// This is the *debounced* lifecycle signal used for orchestration
  /// decisions — distinct from [BridgePluginApi.healthCheck], which is an
  /// instantaneous plugin-scoped probe.
  ///
  /// Transitions follow the state machine documented on [PluginStatus];
  /// in particular `Failed` can never follow `Stopping`.
  Stream<PluginStatus> get status;

  /// The latest [status] value, synchronously.
  PluginStatus get currentStatus;

  /// Cheap, synchronous, side-effect-free diagnostics (endpoint, version).
  PluginDiagnostics describe();

  /// Stops the plugin in order: api teardown, then any managed runtime,
  /// releasing everything `start()` acquired.
  ///
  /// Contract:
  ///
  /// - **Idempotent.** Repeated calls return the same (or an equivalent
  ///   completed) future.
  /// - **Safe in either order with [BridgePluginApi.dispose].** During the
  ///   migration window the bridge core may still call `dispose()` directly
  ///   before or after `shutdown()`; neither call may break the other.
  /// - [budget] is the soft deadline the caller grants; implementations
  ///   should degrade to forceful termination rather than overrun it.
  ///   `null` means the caller imposes no deadline.
  /// - Emits `Stopping` then `Stopped` on [status]; never `Failed`.
  Future<void> shutdown({required Duration? budget});
}
