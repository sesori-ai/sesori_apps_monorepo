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

  late final StreamSubscription<PiProcessSpawnEvent> _spawnEvents;

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

  void _handleSpawnEvent(PiProcessSpawnEvent event) {
    switch (event) {
      case PiProcessSpawnEvent.succeeded:
        markReady();
      case PiProcessSpawnEvent.failed:
        markDegraded(
          recoverable: true,
          requiresUserAction: true,
          userActionHint: "Verify the configured Pi binary and retry.",
        );
    }
  }

  @override
  Future<void> onShutdown({required Duration? budget}) async {
    Object? firstError;
    StackTrace? firstStackTrace;

    Future<void> attempt(Future<void> Function() cleanup) async {
      try {
        await cleanup();
      } on Object catch (error, stackTrace) {
        firstError ??= error;
        firstStackTrace ??= stackTrace;
      }
    }

    try {
      await _spawnEvents.cancel();
    } on Object catch (error, stackTrace) {
      firstError = error;
      firstStackTrace = stackTrace;
    }
    await attempt(() => _plugin.shutdown(shutdownBudget: budget));
    await attempt(_processFactory.dispose);
    final error = firstError;
    if (error != null) Error.throwWithStackTrace(error, firstStackTrace!);
  }
}
