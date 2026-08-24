import "package:sesori_shared/sesori_shared.dart";

import "../repositories/models/session_operation.dart";
import "../repositories/permission_repository.dart";
import "../repositories/question_repository.dart";
import "archived_session_validator.dart";
import "session_operation_dispatcher.dart";

class PendingInteractionService({
  required final PermissionRepository _permissionRepository,
  required final QuestionRepository _questionRepository,
  required final SessionOperationDispatcher _dispatcher,
  required final ArchivedSessionValidator _archivedSessionValidator,
}) {
  var _disposed = false;

  Future<void> replyToPermission({
    required String requestId,
    required String sessionId,
    required PermissionReply reply,
  }) {
    if (_disposed) return _disposedFuture();
    return _dispatcher.dispatch(
      sessionId: sessionId,
      operation: SessionOperation.replyToPermission,
      body: () async {
        await _archivedSessionValidator.requireNotArchived(sessionId: sessionId);
        await _permissionRepository.replyToPermission(
          requestId: requestId,
          sessionId: sessionId,
          reply: reply,
        );
      },
    );
  }

  Future<void> replyToQuestion({
    required String questionId,
    required String sessionId,
    required List<ReplyAnswer> answers,
  }) {
    if (_disposed) return _disposedFuture();
    return _dispatcher.dispatch(
      sessionId: sessionId,
      operation: SessionOperation.replyToQuestion,
      body: () async {
        await _archivedSessionValidator.requireNotArchived(sessionId: sessionId);
        await _questionRepository.replyToQuestion(
          questionId: questionId,
          sessionId: sessionId,
          answers: answers,
        );
      },
    );
  }

  Future<void> rejectQuestion({
    required String questionId,
    required String sessionId,
  }) {
    if (_disposed) return _disposedFuture();
    return _dispatcher.dispatch(
      sessionId: sessionId,
      operation: SessionOperation.rejectQuestion,
      body: () async {
        await _archivedSessionValidator.requireNotArchived(sessionId: sessionId);
        await _questionRepository.rejectQuestion(
          questionId: questionId,
          sessionId: sessionId,
        );
      },
    );
  }

  void dispose() {
    _disposed = true;
  }

  Future<void> _disposedFuture() => Future<void>.error(
    StateError("PendingInteractionService is disposed"),
    StackTrace.current,
  );
}
