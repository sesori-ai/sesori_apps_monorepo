import "dart:async";

import "../repositories/session_repository.dart";

class SessionAbortService {
  final SessionRepository _sessionRepository;
  final StreamController<String> _abortStartedSessionsController = StreamController<String>.broadcast(sync: true);
  final StreamController<String> _abortedSessionsController = StreamController<String>.broadcast(sync: true);
  final StreamController<String> _abortFailedSessionsController = StreamController<String>.broadcast(sync: true);

  SessionAbortService({required SessionRepository sessionRepository}) : _sessionRepository = sessionRepository;

  Stream<String> get abortStartedSessions => _abortStartedSessionsController.stream;
  Stream<String> get abortedSessions => _abortedSessionsController.stream;
  Stream<String> get abortFailedSessions => _abortFailedSessionsController.stream;

  Future<void> abortSession({required String sessionId}) async {
    _abortStartedSessionsController.add(sessionId);
    try {
      await _sessionRepository.abortSession(sessionId: sessionId);
      _abortedSessionsController.add(sessionId);
    } catch (_) {
      _abortFailedSessionsController.add(sessionId);
      rethrow;
    }
  }

  Future<void> dispose() async {
    await _abortStartedSessionsController.close();
    await _abortedSessionsController.close();
    await _abortFailedSessionsController.close();
  }
}
