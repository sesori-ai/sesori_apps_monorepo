import "dart:async";

import "package:sesori_shared/sesori_shared.dart";

import "../repositories/models/session_abort_result.dart";
import "../repositories/models/session_operation.dart";
import "../repositories/session_repository.dart";
import "session_operation_dispatcher.dart";

class SessionAbortService({
  required final SessionRepository _sessionRepository,
  required final SessionOperationDispatcher _dispatcher,
}) {
  final StreamController<String> _abortStartedSessionsController = StreamController<String>.broadcast(sync: true);
  final StreamController<String> _abortedSessionsController = StreamController<String>.broadcast(sync: true);
  final StreamController<String> _abortFailedSessionsController = StreamController<String>.broadcast(sync: true);

  Stream<String> get abortStartedSessions => _abortStartedSessionsController.stream;
  Stream<String> get abortedSessions => _abortedSessionsController.stream;
  Stream<String> get abortFailedSessions => _abortFailedSessionsController.stream;

  /// Stops [sessionId] with the given sub-agent scope.
  ///
  /// Push suppression follows the outcome: only a full stop marks the session
  /// aborted; a rejection or a main-agent-only stop clears the pending mark,
  /// because work that keeps running still earns its completion push.
  Future<SessionAbortResult> abortSession({
    required String sessionId,
    required SessionAbortSubAgentPolicy subAgents,
  }) {
    final operation = _dispatcher.dispatch<SessionAbortResult>(
      sessionId: sessionId,
      operation: SessionOperation.abortSession,
      body: () async {
        final result = await _sessionRepository.abortSession(sessionId: sessionId, subAgents: subAgents);
        // Decided by what the plugin actually did, not by the requested policy:
        // a `keep` with nothing to keep is a full stop.
        if (result case SessionAborted(workKept: false)) {
          _abortedSessionsController.add(sessionId);
        } else {
          _abortFailedSessionsController.add(sessionId);
        }
        return result;
      },
    );
    _abortStartedSessionsController.add(sessionId);
    return operation.then<SessionAbortResult>(
      (result) => result,
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
