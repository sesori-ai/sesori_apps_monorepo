import "dart:async";

import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "../repositories/session_repository.dart";
import "../services/session_options_service.dart";

class SessionOptionsCreationRefreshListener({
  required final Stream<SessionBindingsCommitted> _source,
  required final SessionOptionsService _service,
}) {
  final PendingOperations _pending = PendingOperations();
  StreamSubscription<SessionBindingsCommitted>? _subscription;
  Future<void>? _disposeFuture;
  bool _disposed = false;

  void start() {
    if (_subscription != null || _disposed) return;
    _subscription = _source.listen(
      (commit) {
        if (commit.kind != SessionBindingCommitKind.sessionCreation) return;
        _track(_refresh(commit: commit));
      },
      onError: (Object error, StackTrace stackTrace) {
        Log.w("Session options creation trigger stream failed", error, stackTrace);
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

  Future<void> _refresh({required SessionBindingsCommitted commit}) async {
    try {
      final outcome = await _service.refreshActiveOnly(
        pluginId: commit.pluginId,
        projectId: commit.projectId,
        generation: commit.generation,
      );
      switch (outcome) {
        case SessionOptionsAvailable() ||
            SessionOptionsAutomaticNoOp() ||
            SessionOptionsRefreshFailedRetained() ||
            SessionOptionsRefreshFailedUnavailable():
          return;
        case SessionOptionsProjectNotFound():
          Log.w('Automatic session options refresh found no committed project for plugin "${commit.pluginId}"');
        case SessionOptionsCacheUnavailable():
          Log.w('Automatic session options refresh returned an unexpected cache miss for plugin "${commit.pluginId}"');
      }
    } on Object catch (error, stackTrace) {
      Log.w(
        'Automatic session options refresh failed after session creation for plugin "${commit.pluginId}"',
        error,
        stackTrace,
      );
    }
  }
}
