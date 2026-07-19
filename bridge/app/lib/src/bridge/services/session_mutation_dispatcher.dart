import "dart:async";

import "package:sesori_shared/sesori_shared.dart";

import "../repositories/session_repository.dart";

/// Serializes bridge-owned session mutations that share pending-title state.
class SessionMutationDispatcher {
  final SessionRepository _sessionRepository;
  final StreamController<Session> _deletedSessionsController = StreamController<Session>.broadcast(sync: true);
  final Map<String, _PendingSessionTitle> _pendingTitles = {};
  Future<void> _tail = Future<void>.value();
  bool _disposed = false;

  SessionMutationDispatcher({required SessionRepository sessionRepository}) : _sessionRepository = sessionRepository;

  Stream<Session> get deletedSessions => _deletedSessionsController.stream;

  Future<void> captureTitle({
    required String sessionId,
    required String? title,
    required String pluginId,
    required int generation,
  }) {
    return _serialized(() async {
      await _captureTitle(
        sessionId: sessionId,
        title: title,
        sourcePluginId: pluginId,
        sourceGeneration: generation,
      );
    });
  }

  Future<Session> renameSession({required String sessionId, required String title}) {
    return _serialized(() async {
      final renamed = await _sessionRepository.renameSession(sessionId: sessionId, title: title);
      await _captureTitle(
        sessionId: sessionId,
        title: title,
        sourcePluginId: null,
        sourceGeneration: null,
      );
      return _sessionRepository.enrichSession(session: renamed);
    });
  }

  Future<void> applyPendingTitle({required String sessionId}) {
    return _serialized(() async {
      final pending = _pendingTitles[sessionId];
      if (pending == null) return;
      final result = await _sessionRepository.setSessionTitleIfStored(
        sessionId: sessionId,
        title: pending.title,
        sourcePluginId: pending.sourcePluginId,
        sourceGeneration: pending.sourceGeneration,
      );
      if (result != SessionTitleWriteResult.sessionMissing && identical(_pendingTitles[sessionId], pending)) {
        _pendingTitles.remove(sessionId);
      }
    });
  }

  Future<void> deleteSession({required String sessionId}) {
    if (_disposed) return Future.error(StateError("SessionMutationDispatcher is disposed"));
    return _serialized(() async {
      final deleted = await _sessionRepository.deleteSession(sessionId: sessionId);
      _pendingTitles.remove(sessionId);
      _deletedSessionsController.add(deleted);
    });
  }

  Future<void> dispose() {
    if (_disposed) return Future.value();
    _disposed = true;
    return _serialized(_deletedSessionsController.close);
  }

  Future<void> _captureTitle({
    required String sessionId,
    required String? title,
    required String? sourcePluginId,
    required int? sourceGeneration,
  }) async {
    if (await _sessionRepository.isSessionTombstoned(sessionId: sessionId)) return;
    final result = await _sessionRepository.setSessionTitleIfStored(
      sessionId: sessionId,
      title: title,
      sourcePluginId: sourcePluginId,
      sourceGeneration: sourceGeneration,
    );
    if (result == SessionTitleWriteResult.sessionMissing) {
      _pendingTitles[sessionId] = _PendingSessionTitle(
        title: title,
        sourcePluginId: sourcePluginId,
        sourceGeneration: sourceGeneration,
      );
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
}

class _PendingSessionTitle {
  const _PendingSessionTitle({
    required this.title,
    required this.sourcePluginId,
    required this.sourceGeneration,
  });

  final String? title;
  final String? sourcePluginId;
  final int? sourceGeneration;
}
