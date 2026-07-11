import "dart:async";

import "package:sesori_shared/sesori_shared.dart";

import "../repositories/session_repository.dart";

/// Serializes bridge-owned session mutations that share pending-title state.
class SessionMutationDispatcher {
  final SessionRepository _sessionRepository;
  final Map<String, String?> _pendingTitles = {};
  Future<void> _tail = Future<void>.value();

  SessionMutationDispatcher({required SessionRepository sessionRepository}) : _sessionRepository = sessionRepository;

  Future<void> captureTitle({required String sessionId, required String? title}) {
    return _serialized(() async {
      await _captureTitle(sessionId: sessionId, title: title);
    });
  }

  Future<Session> renameSession({required String sessionId, required String title}) {
    return _serialized(() async {
      final renamed = await _sessionRepository.renameSession(sessionId: sessionId, title: title);
      await _captureTitle(sessionId: sessionId, title: title);
      return _sessionRepository.enrichSession(session: renamed);
    });
  }

  Future<void> applyPendingTitle({required String sessionId}) {
    return _serialized(() async {
      if (!_pendingTitles.containsKey(sessionId)) return;
      final stored = await _sessionRepository.setSessionTitleIfStored(
        sessionId: sessionId,
        title: _pendingTitles[sessionId],
      );
      if (stored) _pendingTitles.remove(sessionId);
    });
  }

  Future<void> deleteSession({required String sessionId}) {
    return _serialized(() async {
      await _sessionRepository.deleteSession(sessionId: sessionId);
      _pendingTitles.remove(sessionId);
    });
  }

  Future<void> _captureTitle({required String sessionId, required String? title}) async {
    if (await _sessionRepository.isSessionTombstoned(sessionId: sessionId)) return;
    final stored = await _sessionRepository.setSessionTitleIfStored(
      sessionId: sessionId,
      title: title,
    );
    if (!stored) _pendingTitles[sessionId] = title;
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
