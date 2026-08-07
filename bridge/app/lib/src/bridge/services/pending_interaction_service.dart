import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show PluginOperationException;
import "package:sesori_shared/sesori_shared.dart";

import "../repositories/models/session_operation.dart";
import "../repositories/permission_repository.dart";
import "../repositories/question_repository.dart";
import "archived_session_validator.dart";
import "session_operation_dispatcher.dart";

class PendingInteractionService {
  final PermissionRepository _permissionRepository;
  final QuestionRepository _questionRepository;
  final SessionOperationDispatcher _dispatcher;
  final ArchivedSessionValidator _archivedSessionValidator;
  final String _legacyMissingPluginId;
  var _disposed = false;

  PendingInteractionService({
    required PermissionRepository permissionRepository,
    required QuestionRepository questionRepository,
    required SessionOperationDispatcher dispatcher,
    required ArchivedSessionValidator archivedSessionValidator,
    required String legacyMissingPluginId,
  }) : _permissionRepository = permissionRepository,
       _questionRepository = questionRepository,
       _dispatcher = dispatcher,
       _archivedSessionValidator = archivedSessionValidator,
       _legacyMissingPluginId = legacyMissingPluginId;

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
        await _archivedSessionValidator.requireNotArchived(
          sessionId: sessionId,
          operation: SessionOperation.replyToPermission,
        );
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
        await _archivedSessionValidator.requireNotArchived(
          sessionId: sessionId,
          operation: SessionOperation.replyToQuestion,
        );
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
    required String? sessionId,
  }) {
    if (_disposed) return _disposedFuture();
    if (sessionId != null) {
      return _dispatcher.dispatch(
        sessionId: sessionId,
        operation: SessionOperation.rejectQuestion,
        body: () async {
          await _archivedSessionValidator.requireNotArchived(
            sessionId: sessionId,
            operation: SessionOperation.rejectQuestion,
          );
          await _questionRepository.rejectQuestion(
            questionId: questionId,
            sessionId: sessionId,
          );
        },
      );
    }

    // COMPATIBILITY 2026-06-17 (v1.1.0): Released clients may omit the rejection sessionId. Require it and remove legacy owner resolution once those clients are unsupported.
    return _dispatcher.dispatchLegacyQuestion(
      pluginId: _legacyMissingPluginId,
      questionId: questionId,
      operation: SessionOperation.rejectQuestion,
      resolveOwnerSessionId: () async {
        final owners = await _questionRepository.findPendingQuestionOwnerSessionIds(
          pluginId: _legacyMissingPluginId,
          questionId: questionId,
        );
        if (owners.isEmpty) {
          throw PluginOperationException.notFound(
            SessionOperation.rejectQuestion.name,
            message: "pending question $questionId was not found for legacy rejection",
          );
        }
        if (owners.length > 1) {
          throw PluginOperationException(
            SessionOperation.rejectQuestion.name,
            statusCode: 409,
            message: "pending question $questionId has multiple owners for legacy rejection",
          );
        }
        return owners.single;
      },
      body: ({required ownerSessionId}) async {
        // The archive rule is uniform: a resolved legacy owner is checked the
        // same way an explicit session id is.
        await _archivedSessionValidator.requireNotArchived(
          sessionId: ownerSessionId,
          operation: SessionOperation.rejectQuestion,
        );
        await _questionRepository.rejectQuestion(
          questionId: questionId,
          sessionId: ownerSessionId,
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
