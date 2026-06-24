import "../lifecycle/plugin_config.dart";
import "../lifecycle/start_abort_signal.dart";
import "../process/server_clock.dart";
import "bridge_host_info.dart";
import "host_json_store.dart";
import "host_port_service.dart";
import "host_process_service.dart";

/// Services the bridge offers to a starting plugin.
///
/// Handed to `BridgePluginDescriptor.start`. Every service is opt-in: a
/// plugin that talks to a remote server may only ever touch [config], while
/// a plugin that manages a local runtime uses processes, ports, and the
/// JSON store. Plugins must not reach around the host (spawning processes or
/// writing state files directly) — the host's seams are what make plugin
/// lifecycles testable and let the bridge enforce its cross-version on-disk
/// contracts.
abstract class PluginHost {
  /// Parsed values of the options this plugin declared.
  PluginConfig get config;

  /// Absolute path of this plugin's private state directory. Created by the
  /// bridge before `start()` runs. Files managed through [store] live here.
  String get stateDirectory;

  /// The runtime launch path resolved by `BridgePluginDescriptor.ensureRuntime`
  /// (an absolute managed-binary path, an explicit override, or a PATH-resolved
  /// command), or `null` when the plugin did no provisioning or it failed. The
  /// bridge sets this between `ensureRuntime` and `start`; `start` reads it to
  /// launch the backend.
  String? get provisionedRuntimePath;

  /// The process environment the bridge was started with.
  Map<String, String> get environment;

  /// Clock seam — plugins should use this (not `DateTime.now` /
  /// `Future.delayed`) so lifecycle timing is testable.
  ServerClock get clock;

  /// Cooperative abort signal for the current `start()` call.
  ///
  /// The bridge holds its cross-instance startup mutex until `start()`
  /// settles — it never abandons a start with `Future.timeout`. Instead it
  /// asks the plugin to abort through this signal; `start()` must check it
  /// at every phase boundary and roll back everything acquired so far.
  StartAbortSignal get startAborted;

  /// Identity facts about the hosting bridge process, including the
  /// live-bridge classification capability used to authorize stale-runtime
  /// cleanup.
  BridgeHostInfo get bridge;

  /// Spawn, inspect, and signal OS processes.
  HostProcessService get processes;

  /// Probe loopback ports.
  HostPortService get ports;

  /// Atomic JSON-file persistence under [stateDirectory], with a locked
  /// read-modify-write primitive.
  HostJsonStore get store;
}
