import "dart:async";

import "../repositories/models/session_operation.dart";
import "../repositories/session_repository.dart";
import "session_operation_dispatcher.dart";

class SessionAbortService {
  final SessionRepository _sessionRepository;
  final SessionOperationDispatcher _dispatcher;
  final StreamController<String> _abortStartedSessionsController = StreamController<String>.broadcast(sync: true);
  final StreamController<String> _abortedSessionsController = StreamController<String>.broadcast(sync: true);
  final StreamController<String> _abortFailedSessionsController = StreamController<String>.broadcast(sync: true);

  SessionAbortService({
    required SessionRepository sessionRepository,
    required SessionOperationDispatcher dispatcher,
  }) : _sessionRepository = sessionRepository,
       _dispatcher = dispatcher;

  Stream<String> get abortStartedSessions => _abortStartedSessionsController.stream;
  Stream<String> get abortedSessions => _abortedSessionsController.stream;
  Stream<String> get abortFailedSessions => _abortFailedSessionsController.stream;

  Future<void> abortSession({required String sessionId}) {
    final operation = _dispatcher.dispatch<void>(
      sessionId: sessionId,
      operation: SessionOperation.abortSession,
      interaction: null,
      body: () async {
        await _sessionRepository.abortSession(sessionId: sessionId);
        _abortedSessionsController.add(sessionId);
      },
    );
    _abortStartedSessionsController.add(sessionId);
    return operation.then<void>(
      (_) {},
      onError: (Object error, StackTrace stackTrace) {
        _abortFailedSessionsController.add(sessionId);
        Error.throwWithStackTrace(error, stackTrace);
      },
    );
  }

  Future<void> dispose() async {
    await _abortStartedSessionsController.close();
    await _abortedSessionsController.close();
    await _abortFailedSessionsController.close();
  }
}
