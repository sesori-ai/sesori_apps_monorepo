import "package:sesori_shared/sesori_shared.dart";

import "../repositories/external_action_repository.dart";
import "../repositories/models/session_operation.dart";
import "../repositories/permission_repository.dart";
import "../repositories/question_repository.dart";
import "archived_session_validator.dart";
import "session_operation_dispatcher.dart";

class PendingInteractionService({
  required final PermissionRepository _permissionRepository,
  required final QuestionRepository _questionRepository,
  required final ExternalActionRepository _externalActionRepository,
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

  Future<ExternalActionReplyResult> replyToExternalAction({required ReplyToExternalActionRequest request}) {
    if (_disposed) return _disposedFuture();
    return _dispatcher.dispatch(
      sessionId: request.sessionId,
      operation: SessionOperation.replyToExternalAction,
      body: () async {
        await _archivedSessionValidator.requireNotArchived(sessionId: request.sessionId);
        return await _externalActionRepository.reply(request: request);
      },
    );
  }

  void dispose() {
    _disposed = true;
  }

  Future<T> _disposedFuture<T>() => Future<T>.error(
    StateError("PendingInteractionService is disposed"),
    StackTrace.current,
  );
}
