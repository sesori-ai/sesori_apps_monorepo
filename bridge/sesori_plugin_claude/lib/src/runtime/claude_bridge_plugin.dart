import "dart:async";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "../api/claude_process_factory.dart";
import "../claude_plugin_impl.dart";
import "../services/claude_session_service.dart";

/// Lifecycle surface for the direct-CLI Claude stream-json plugin.
final class ClaudeBridgePlugin({
  required final ClaudePlugin _plugin,
  required final ClaudeSessionService _sessions,
  required final HostClaudeProcessFactory _processFactory,
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
  Stream<PluginWorkState> get workState => _sessions.workState;

  @override
  PluginWorkState get currentWorkState => _sessions.currentWorkState;

  @override
  ServerClock get statusClock => _clock;

  @override
  Duration get degradedDebounce => _statusDebounce;

  @override
  PluginDiagnostics describe() => const PluginDiagnostics(
    pluginId: ClaudePlugin.pluginId,
    endpoint: null,
    details: {"transport": "claude-stream-json"},
  );

  @override
  Future<Set<String>> interruptActiveWork({required Duration budget}) => _sessions.interruptActiveWork(budget: budget);

  void _handleSpawnEvent(ProcessSpawnOutcome event) {
    switch (event) {
      case ProcessSpawnOutcome.succeeded:
        markReady();
      case ProcessSpawnOutcome.failed:
        markDegraded(
          recoverable: true,
          requiresUserAction: true,
          userActionHint: "Verify the configured Claude binary and retry.",
        );
    }
  }

  @override
  Future<void> onShutdown({required Duration? budget}) => runShutdownCleanups(
    cleanups: [_spawnEvents.cancel, _plugin.dispose, _processFactory.dispose],
  );
}
