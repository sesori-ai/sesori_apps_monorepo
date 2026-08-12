import "dart:async";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "../api/claude_process_factory.dart";
import "../claude_plugin_impl.dart";
import "../services/claude_session_service.dart";

/// Lifecycle surface for the direct-CLI Claude stream-json plugin.
final class ClaudeBridgePlugin({
    required ClaudePlugin plugin,
    required ClaudeSessionService sessions,
    required HostClaudeProcessFactory processFactory,
    required ServerClock clock,
    required Duration statusDebounce,
  }) with SteadyPluginLifecycle implements BridgePlugin {
  this : _plugin = plugin,
       _sessions = sessions,
       _processFactory = processFactory,
       _clock = clock,
       _statusDebounce = statusDebounce {
    _spawnEvents = processFactory.events.listen(_handleSpawnEvent);
    markReady();
  }

  final ClaudePlugin _plugin;
  final ClaudeSessionService _sessions;
  final HostClaudeProcessFactory _processFactory;
  final ServerClock _clock;
  final Duration _statusDebounce;
  late final StreamSubscription<ClaudeProcessSpawnEvent> _spawnEvents;

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

  void _handleSpawnEvent(ClaudeProcessSpawnEvent event) {
    switch (event) {
      case ClaudeProcessSpawnSucceeded():
        markReady();
      case ClaudeProcessSpawnFailed():
        markDegraded(
          recoverable: true,
          requiresUserAction: true,
          userActionHint: "Verify the configured Claude binary and retry.",
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
    await attempt(_plugin.dispose);
    await attempt(_processFactory.dispose);
    final error = firstError;
    if (error != null) Error.throwWithStackTrace(error, firstStackTrace!);
  }
}
