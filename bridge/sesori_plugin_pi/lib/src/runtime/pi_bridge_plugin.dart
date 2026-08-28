import "dart:async";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "../api/pi_process_factory.dart";
import "../pi_plugin_impl.dart";

/// Lifecycle surface for Pi's lazy per-session JSONL RPC processes.
final class PiBridgePlugin({
  required final PiPlugin _plugin,
  required final HostPiProcessFactory _processFactory,
  required final ServerClock _clock,
  required final Duration _statusDebounce,
}) with SteadyPluginLifecycle implements BridgePlugin {
  this {
    _spawnEvents = _processFactory.events.listen(_handleSpawnEvent);
    markReady();
  }

  // ignore: cancel_subscriptions, cancelled by onShutdown's shared cleanup sequence
  late final StreamSubscription<ProcessSpawnOutcome> _spawnEvents;

  @override
  BridgePluginApi get api => _plugin;

  @override
  Stream<PluginWorkState> get workState => _plugin.workState;

  @override
  PluginWorkState get currentWorkState => _plugin.currentWorkState;

  @override
  ServerClock get statusClock => _clock;

  @override
  Duration get degradedDebounce => _statusDebounce;

  @override
  PluginDiagnostics describe() => const PluginDiagnostics(
    pluginId: PiPlugin.pluginId,
    endpoint: null,
    details: {"transport": "pi-jsonl-rpc"},
  );

  @override
  Future<Set<String>> interruptActiveWork({required Duration budget}) => _plugin.interruptActiveWork(budget: budget);

  void _handleSpawnEvent(ProcessSpawnOutcome event) {
    switch (event) {
      case ProcessSpawnOutcome.succeeded:
        markReady();
      case ProcessSpawnOutcome.failed:
        markDegraded(
          recoverable: true,
          requiresUserAction: true,
          userActionHint: "Verify the configured Pi binary and retry.",
        );
    }
  }

  @override
  Future<void> onShutdown({required Duration? budget}) => runShutdownCleanups(
    cleanups: [
      _spawnEvents.cancel,
      () => _plugin.shutdown(shutdownBudget: budget),
      _processFactory.dispose,
    ],
  );
}
