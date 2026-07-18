import "package:meta/meta.dart";

import "../host/host_process_service.dart";
import "../host/plugin_host.dart";
import "bridge_plugin.dart";
import "plugin_availability.dart";
import "plugin_config.dart";
import "plugin_option.dart";
import "plugin_state_storage.dart";
import "runtime_provision_progress.dart";

/// The registration unit for a bridge plugin.
///
/// Descriptors are const and inert: constructing or registering one has no
/// side effects. **Registered is not started** — the bridge starts only the
/// selected/enabled subset of registered descriptors, and every enabled
/// descriptor contributes its [options] to the CLI parser.
@immutable
abstract class BridgePluginDescriptor {
  const BridgePluginDescriptor();

  /// Stable plugin identifier (e.g. `"opencode"`). Must match the id of the
  /// `BridgePluginApi` the started plugin exposes.
  String get id;

  /// Human-readable name for logs and help output.
  String get displayName;

  /// Layout used for the plugin's private host state.
  ///
  /// New plugins are isolated by default. Plugins with shipped state in the
  /// legacy shared runtime directory can preserve that location explicitly.
  PluginStateStorage get stateStorage => PluginStateStorage.isolated;

  /// CLI options this plugin contributes when selected.
  List<PluginOption> get options;

  /// Validates [config] before the bridge takes any irreversible step.
  ///
  /// Runs at argument-parse time — strictly *before* the startup mutex is
  /// acquired and before any already-running bridge could be replaced, so a
  /// config typo can never terminate a healthy resident bridge. Throw
  /// [PluginConfigException] to reject the configuration with a usage error.
  ///
  /// Must be pure: no I/O, no side effects. The default accepts everything.
  void validateConfig(PluginConfig config) {}

  /// Reports whether this plugin's backend is available to run.
  ///
  /// Runs after authentication but **before** the cross-instance startup mutex
  /// and before [start], so an unavailable backend never terminates a healthy
  /// resident bridge (the same invariant that keeps [validateConfig] ahead of
  /// the mutex). Must be read-only — probe only, acquire nothing.
  ///
  /// Return [PluginUnavailable] with a user-facing [PluginUnavailable.message]
  /// (install guidance plus a verification command) when the backend cannot be
  /// used; the bridge core prints that message via `Console.error` and skips
  /// this descriptor. Startup fails only when no enabled descriptor is
  /// available. Return [PluginAvailable] to let this descriptor proceed.
  ///
  /// [config] carries the parsed CLI options, [processes] lets a plugin probe a
  /// local binary (e.g. run `--version`), and [environment] is the process
  /// environment (PATH, etc.). The default accepts everything, which suits
  /// plugins that need no local backend (e.g. remote-server plugins).
  Future<PluginAvailability> checkAvailability({
    required PluginConfig config,
    required HostProcessService processes,
    required Map<String, String> environment,
  }) async => const PluginAvailable();

  /// Ensures the plugin's backend runtime is installed and runnable, acquiring
  /// (e.g. downloading) it when necessary, and reports progress.
  ///
  /// Runs after [checkAvailability] returns [PluginAvailable] and immediately
  /// before [start] — under the bridge's startup mutex, so concurrent bridge
  /// instances can never install the same managed runtime at once. The stream's
  /// final event is terminal: [ProvisionReady] carries the resolved launch path,
  /// which the bridge exposes to [start] via [PluginHost.provisionedRuntimePath];
  /// [ProvisionFailed] is **non-fatal** — the bridge proceeds to [start], which
  /// reports a degraded status rather than terminating a healthy resident bridge.
  ///
  /// Provisioning must observe [PluginHost.startAborted] at each phase boundary
  /// so a slow download can be cancelled. The default emits nothing, which suits
  /// plugins that need no runtime acquisition (remote-server or attach-mode
  /// plugins).
  Stream<RuntimeProvisionProgress> ensureRuntime({required PluginHost host}) {
    return const Stream<RuntimeProvisionProgress>.empty();
  }

  /// Starts the plugin and returns its live instance.
  ///
  /// Contract:
  ///
  /// - Runs under the bridge's cross-instance startup mutex; the mutex is
  ///   held until every enabled descriptor's start settles. The bridge never abandons a start
  ///   with `Future.timeout` — long-running phases must observe
  ///   [PluginHost.startAborted] at every phase boundary and roll back when
  ///   aborted. An aborted start settles by throwing
  ///   `PluginStartAbortedException` after the rollback.
  /// - On failure, release *everything* acquired (processes, records,
  ///   sockets) before throwing — `PluginStartException` for expected
  ///   failure modes.
  /// - The returned plugin should already be usable; if full readiness is
  ///   established asynchronously, return with status `Starting`/`Degraded`
  ///   and let the status stream report progress.
  Future<BridgePlugin> start(PluginHost host);
}
