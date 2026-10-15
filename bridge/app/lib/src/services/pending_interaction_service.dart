import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../repositories/external_action_repository.dart";
import "../repositories/form_repository.dart";
import "../repositories/models/session_operation.dart";
import "../repositories/permission_repository.dart";
import "../repositories/question_repository.dart";
import "archived_session_validator.dart";
import "session_operation_dispatcher.dart";

class PendingInteractionService({
  required final PermissionRepository _permissionRepository,
  required final QuestionRepository _questionRepository,
  required final ExternalActionRepository _externalActionRepository,
  required final FormRepository _formRepository,
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

  Future<List<PendingExternalAction>> getPendingExternalActions({required String sessionId}) async {
    if (_disposed) return await _disposedFuture();
    final actions = await _externalActionRepository.getPending(sessionId: sessionId);
    for (final action in actions) {
      _requireSafeDestination(action: action, operation: SessionOperation.getPendingExternalActions);
    }
    return actions;
  }

  Future<ExternalActionReplyResult> replyToExternalAction({required ReplyToExternalActionRequest request}) {
    if (_disposed) return _disposedFuture();
    return _dispatcher.dispatch(
      sessionId: request.sessionId,
      operation: SessionOperation.replyToExternalAction,
      body: () async {
        await _archivedSessionValidator.requireNotArchived(sessionId: request.sessionId);
        if (request.choice == ExternalActionChoice.accept) {
          for (final action in await _externalActionRepository.getPending(sessionId: request.sessionId)) {
            if (action.id != request.requestId || action.sessionID != request.sessionId) continue;
            _requireSafeDestination(action: action, operation: SessionOperation.replyToExternalAction);
            return await _externalActionRepository.reply(request: request);
          }
          return const ExternalActionAlreadySettled();
        }
        return await _externalActionRepository.reply(request: request);
      },
    );
  }

  Future<List<PendingForm>> getPendingForms({required String sessionId}) async {
    if (_disposed) return await _disposedFuture();
    return await _formRepository.getPending(sessionId: sessionId);
  }

  Future<FormReplyResult> replyToForm({required ReplyToFormRequest request}) {
    if (_disposed) return _disposedFuture();
    return _dispatcher.dispatch(
      sessionId: request.sessionId,
      operation: SessionOperation.replyToForm,
      body: () async {
        await _archivedSessionValidator.requireNotArchived(sessionId: request.sessionId);
        return await _formRepository.reply(request: request);
      },
    );
  }

  Future<FormReplyResult> declineForm({required DeclineFormRequest request}) {
    if (_disposed) return _disposedFuture();
    return _dispatcher.dispatch(
      sessionId: request.sessionId,
      operation: SessionOperation.declineForm,
      body: () async {
        await _archivedSessionValidator.requireNotArchived(sessionId: request.sessionId);
        return await _formRepository.decline(request: request);
      },
    );
  }

  void dispose() {
    _disposed = true;
  }

  void _requireSafeDestination({required PendingExternalAction action, required SessionOperation operation}) {
    final uri = Uri.tryParse(action.authorizationUrl);
    if (uri != null && uri.scheme == "https" && uri.hasAuthority && uri.host.isNotEmpty && uri.userInfo.isEmpty) return;
    Log.w(
      "Rejecting external-action destination for ${action.id} in ${action.sessionID}: HTTPS without user info required",
    );
    throw PluginOperationException(
      operation.name,
      statusCode: 422,
      message: "external-action destination requires absolute HTTPS without user info",
    );
  }

  Future<T> _disposedFuture<T>() => Future<T>.error(
    StateError("PendingInteractionService is disposed"),
    StackTrace.current,
  );
}
