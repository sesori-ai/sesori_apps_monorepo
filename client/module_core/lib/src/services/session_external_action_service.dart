import "package:injectable/injectable.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../repositories/session_repository.dart";

/// Reads and answers one native request without owning its lifetime.
@lazySingleton
class SessionExternalActionService({required final SessionRepository _repository}) {
  Future<PendingExternalAction?> read({required String requestId, required String sessionId}) async {
    switch (await _repository.getPendingExternalActions(sessionId: sessionId)) {
      case SuccessResponse(:final data):
        for (final action in data.data) {
          if (action.id == requestId && action.sessionID == sessionId) return action;
        }
        return null;
      case ErrorResponse(:final error):
        throw error;
    }
  }

  Uri? browserDestination({required PendingExternalAction action}) {
    if (action.purpose == ExternalActionPurpose.unknown) return null;
    final uri = Uri.tryParse(action.authorizationUrl);
    return uri != null && uri.scheme == "https" && uri.hasAuthority && uri.host.isNotEmpty && uri.userInfo.isEmpty
        ? uri
        : null;
  }

  Future<ExternalActionReplyResult> reply({
    required PendingExternalAction action,
    required ExternalActionChoice choice,
  }) async {
    if (choice == ExternalActionChoice.unknown ||
        !action.choices.contains(choice) ||
        (choice == ExternalActionChoice.accept && browserDestination(action: action) == null)) {
      return const ExternalActionUnsupportedChoice();
    }
    return switch (await _repository.replyToExternalAction(
      request: ReplyToExternalActionRequest(
        requestId: action.id,
        sessionId: action.sessionID,
        choice: choice,
      ),
    )) {
      SuccessResponse(:final data) => data,
      ErrorResponse(:final error) => throw error,
    };
  }
}
