import "dart:async";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log, PluginOperationException;
import "package:sesori_shared/sesori_shared.dart";

import "../repositories/models/session_operation.dart";
import "../repositories/session_repository.dart";

/// Serializes bridge-owned session mutations and backend propagation.
class SessionMutationDispatcher {
  final SessionRepository _sessionRepository;
  final StreamController<Session> _deletedSessionsController = StreamController<Session>.broadcast(sync: true);
  Future<void> _tail = Future<void>.value();
  Future<void> _backendTail = Future<void>.value();
  bool _disposed = false;

  SessionMutationDispatcher({required SessionRepository sessionRepository}) : _sessionRepository = sessionRepository;

  Stream<Session> get deletedSessions => _deletedSessionsController.stream;

  /// Completes after the authoritative DB title is stored. Backend propagation
  /// continues on its own serialized tail so later DB writes stay immediate
  /// while delete and dispose still cannot overtake backend synchronization.
  Future<Session> renameSession({required String sessionId, required String title}) {
    return _serialized(() async {
      final stored = await _sessionRepository.setSessionTitleIfStored(sessionId: sessionId, title: title);
      final renamed = stored ? await _sessionRepository.getCatalogSession(sessionId: sessionId) : null;
      if (renamed == null) {
        throw PluginOperationException.notFound(
          SessionOperation.renameSession.name,
          message: "session $sessionId was not found",
        );
      }
      unawaited(
        _serializedBackend(() => _propagateTitle(sessionId: sessionId, title: title)),
      );
      return renamed;
    });
  }

  Future<void> deleteSession({required String sessionId}) {
    if (_disposed) return Future.error(StateError("SessionMutationDispatcher is disposed"));
    return _serialized(() async {
      final deleted = await _serializedBackend(() => _sessionRepository.deleteSession(sessionId: sessionId));
      _deletedSessionsController.add(deleted);
    });
  }

  Future<void> drain() => _serialized(() => _serializedBackend(() async {}));

  Future<void> dispose() {
    if (_disposed) return Future.value();
    _disposed = true;
    return _serialized(() async {
      await _serializedBackend(() async {});
      await _deletedSessionsController.close();
    });
  }

  Future<void> _propagateTitle({
    required String sessionId,
    required String title,
  }) async {
    try {
      await _sessionRepository.renameSession(sessionId: sessionId, title: title);
    } catch (error, stackTrace) {
      Log.w("Could not propagate title for session $sessionId to its plugin", error, stackTrace);
    }
  }

  Future<T> _serialized<T>(Future<T> Function() operation) {
    final previous = _tail;
    final release = Completer<void>();
    _tail = release.future;
    return () async {
      await previous;
      try {
        return await operation();
      } finally {
        release.complete();
      }
    }();
  }

  Future<T> _serializedBackend<T>(Future<T> Function() operation) {
    final previous = _backendTail;
    final release = Completer<void>();
    _backendTail = release.future;
    return () async {
      await previous;
      try {
        return await operation();
      } finally {
        release.complete();
      }
    }();
  }
}
