import "../host/plugin_host.dart";
import "bridge_plugin.dart";
import "plugin_config.dart";
import "plugin_option.dart";

/// The registration unit for a bridge plugin.
///
/// Descriptors are const and inert: constructing or registering one has no
/// side effects. **Registered is not started** — the bridge starts only the
/// selected/enabled subset of registered descriptors, and registers only the
/// selected descriptor's [options] into its CLI parser.
abstract class BridgePluginDescriptor {
  const BridgePluginDescriptor();

  /// Stable plugin identifier (e.g. `"opencode"`). Must match the id of the
  /// `BridgePluginApi` the started plugin exposes.
  String get id;

  /// Human-readable name for logs and help output.
  String get displayName;

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

  /// Starts the plugin and returns its live instance.
  ///
  /// Contract:
  ///
  /// - Runs under the bridge's cross-instance startup mutex; the mutex is
  ///   held until this future settles. The bridge never abandons a start
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
