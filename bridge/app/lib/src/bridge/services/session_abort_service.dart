import "dart:async";

import "../repositories/session_repository.dart";

class SessionAbortService {
  final SessionRepository _sessionRepository;
  final StreamController<String> _abortedSessionsController = StreamController<String>.broadcast(sync: true);

  SessionAbortService({required SessionRepository sessionRepository}) : _sessionRepository = sessionRepository;

  Stream<String> get abortedSessions => _abortedSessionsController.stream;

  Future<void> abortSession({required String sessionId}) async {
    await _sessionRepository.abortSession(sessionId: sessionId);
    _abortedSessionsController.add(sessionId);
  }

  Future<void> dispose() {
    return _abortedSessionsController.close();
  }
}
