import "dart:convert";

import "package:sesori_shared/sesori_shared.dart";

import "../services/session_cleanup_result.dart";
import "../services/session_deletion_service.dart";
import "request_handler.dart";

/// Handles `DELETE /session/delete` — deletes a session.
class DeleteSessionHandler({required SessionDeletionService sessionDeletionService}) extends BodyRequestHandler<DeleteSessionRequest, SuccessEmptyResponse> {
  final SessionDeletionService _sessionDeletionService;

  this
    : _sessionDeletionService = sessionDeletionService,
      super(
        HttpMethod.delete,
        "/session/delete",
        fromJson: DeleteSessionRequest.fromJson,
      );

  @override
  Future<SuccessEmptyResponse> handle(
    RelayRequest request, {
    required DeleteSessionRequest body,
    required Map<String, String> pathParams,
    required Map<String, String> queryParams,
    required String? fragment,
  }) async {
    final sessionId = body.sessionId;
    if (sessionId.isEmpty) {
      throw buildErrorResponse(request, 400, "empty session id");
    }

    final cleanupResult = await _sessionDeletionService.deleteSession(
      sessionId: sessionId,
      deleteWorktree: body.deleteWorktree,
      deleteBranch: body.deleteBranch,
      force: body.force,
    );
    if (cleanupResult case CleanupRejected(:final rejection)) {
      // IMPORTANT: Do not change this response structure — the mobile app
      // parses the 409 body as SessionCleanupRejection JSON.
      throw RelayResponse(
        id: request.id,
        status: 409,
        headers: {"content-type": "application/json"},
        body: jsonEncode(rejection.toJson()),
      );
    }

    return const SuccessEmptyResponse();
  }
}
