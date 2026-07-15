import "dart:convert";

import "package:sesori_shared/sesori_shared.dart";

import "../services/session_cleanup_service.dart";
import "../services/session_mutation_dispatcher.dart";
import "request_handler.dart";

/// Handles `DELETE /session/delete` — deletes a session.
class DeleteSessionHandler extends BodyRequestHandler<DeleteSessionRequest, SuccessEmptyResponse> {
  final SessionCleanupService _sessionCleanupService;
  final SessionMutationDispatcher _sessionMutationDispatcher;

  DeleteSessionHandler({
    required SessionCleanupService sessionCleanupService,
    required SessionMutationDispatcher sessionMutationDispatcher,
  }) : _sessionCleanupService = sessionCleanupService,
       _sessionMutationDispatcher = sessionMutationDispatcher,
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

    final cleanupResult = await _sessionCleanupService.cleanup(
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

    // Unconditional (not gated on a stored row): the repository delete also
    // records the tombstone, and a rowless-but-enumerable backend session
    // still needs one or it reappears from the next enumeration.
    await _sessionMutationDispatcher.deleteSession(sessionId: sessionId);

    return const SuccessEmptyResponse();
  }
}
