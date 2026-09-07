import "dart:async";

import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "../runtime/plugin_runtime.dart";
import "../services/session_options_service.dart";

class SessionOptionsChangedRefreshListener({
  required final PluginRuntime _runtime,
  required final SessionOptionsService _service,
}) {
  final PendingOperations _pending = PendingOperations();
  StreamSubscription<SourcedPluginRuntimeEvent>? _subscription;
  Future<void>? _disposeFuture;
  bool _disposed = false;

  void start() {
    if (_subscription != null || _disposed) return;
    _subscription = _runtime.backendEvents.listen(
      (source) {
        // Resolve the work before fencing on the generation, so an unrelated
        // event costs nothing beyond the match.
        final refresh = switch (source.event) {
          BridgeSseSessionOptionsChanged(:final sessionID) => () => _refresh(
            pluginId: source.pluginId,
            backendSessionId: sessionID,
            generation: source.generation,
          ),
          // Named no session, so every project this plugin has a cached catalog
          // for could be affected.
          BridgeSseCommandCatalogUpdated() => () => _refreshCachedProjects(
            pluginId: source.pluginId,
            generation: source.generation,
          ),
          _ => null,
        };
        if (refresh == null) return;
        if (!_runtime.isCurrentGeneration(pluginId: source.pluginId, generation: source.generation)) return;
        _track(refresh());
      },
      onError: (Object error, StackTrace stackTrace) {
        Log.w("Session options change trigger stream failed", error, stackTrace);
      },
    );
  }

  Future<void> dispose() => _disposeFuture ??= _dispose();

  Future<void> _dispose() async {
    _disposed = true;
    await _subscription?.cancel();
    await _pending.drain();
  }

  void _track(Future<void> operation) {
    unawaited(_pending.track(operation: operation));
  }

  Future<void> _refreshCachedProjects({
    required String pluginId,
    required int generation,
  }) async {
    try {
      await _service.refreshActiveOnlyForCachedProjects(pluginId: pluginId, generation: generation);
    } on Object catch (error, stackTrace) {
      Log.w(
        'Automatic session options refresh failed after a command catalog change for plugin "$pluginId"',
        error,
        stackTrace,
      );
    }
  }

  Future<void> _refresh({
    required String pluginId,
    required String backendSessionId,
    required int generation,
  }) async {
    try {
      final outcome = await _service.refreshActiveOnlyForBackendSession(
        pluginId: pluginId,
        backendSessionId: backendSessionId,
        generation: generation,
      );
      switch (outcome) {
        case SessionOptionsAvailable() ||
            SessionOptionsAutomaticNoOp() ||
            SessionOptionsRefreshFailedRetained() ||
            SessionOptionsRefreshFailedUnavailable():
          return;
        case SessionOptionsProjectNotFound():
          Log.w('Automatic session options refresh found no bound project for plugin "$pluginId"');
        case SessionOptionsCacheUnavailable():
          Log.w('Automatic session options refresh returned an unexpected cache miss for plugin "$pluginId"');
      }
    } on Object catch (error, stackTrace) {
      Log.w(
        'Automatic session options refresh failed after an options-change event for plugin "$pluginId"',
        error,
        stackTrace,
      );
    }
  }
}
