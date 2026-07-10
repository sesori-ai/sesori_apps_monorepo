import "dart:async";

import "../repositories/session_repository.dart";

/// Coordinates bridge-owned title updates that can race session persistence.
class SessionTitleService {
  final SessionRepository _sessionRepository;
  final Map<String, String?> _pendingTitles = {};
  Future<void> _tail = Future<void>.value();

  SessionTitleService({required SessionRepository sessionRepository})
    : _sessionRepository = sessionRepository;

  Future<void> captureTitle({required String sessionId, required String? title}) {
    return _serialized(() async {
      if (await _sessionRepository.isSessionTombstoned(sessionId: sessionId)) return;
      final stored = await _sessionRepository.setSessionTitleIfStored(
        sessionId: sessionId,
        title: title,
      );
      if (!stored) _pendingTitles[sessionId] = title;
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
