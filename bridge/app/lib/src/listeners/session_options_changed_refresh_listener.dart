import "dart:async";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "../bridge/runtime/plugin_runtime.dart";
import "../bridge/services/session_options_service.dart";

class SessionOptionsChangedRefreshListener({
    required PluginRuntime runtime,
    required SessionOptionsService service,
  }) {
  this : _runtime = runtime,
       _service = service;

  final PluginRuntime _runtime;
  final SessionOptionsService _service;
  final Set<Future<void>> _pending = {};
  StreamSubscription<SourcedPluginRuntimeEvent>? _subscription;
  Future<void>? _disposeFuture;
  bool _disposed = false;

  void start() {
    if (_subscription != null || _disposed) return;
    _subscription = _runtime.backendEvents.listen(
      (source) {
        final event = source.event;
        if (event is! BridgeSseSessionOptionsChanged ||
            !_runtime.isCurrentGeneration(pluginId: source.pluginId, generation: source.generation)) {
          return;
        }
        _track(
          _refresh(
            pluginId: source.pluginId,
            backendSessionId: event.sessionID,
            generation: source.generation,
          ),
        );
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
    await Future.wait(_pending.toList(growable: false));
  }

  void _track(Future<void> operation) {
    _pending.add(operation);
    unawaited(operation.whenComplete(() => _pending.remove(operation)));
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
