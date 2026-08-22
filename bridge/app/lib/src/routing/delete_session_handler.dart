import "package:sesori_shared/sesori_shared.dart";

import "../services/session_cleanup_result.dart";
import "../services/session_deletion_service.dart";
import "request_handler.dart";

/// Handles `DELETE /session/delete` — deletes a session.
class DeleteSessionHandler({required final SessionDeletionService _sessionDeletionService})
    extends BodyRequestHandler<DeleteSessionRequest, SuccessEmptyResponse> {
  this
    : super(
        HttpMethod.delete,
        "/session/delete",
        fromJson: DeleteSessionRequest.fromJson,
      );

  @override
  Future<SuccessEmptyResponse> handle(
    RelayRequest request, {
    required DeleteSessionRequest body,
  }) async {
    final sessionId = body.sessionId;
    requireNonEmpty(request, sessionId, "session id");

    // COMPATIBILITY 2026-08-13 (v1.7.1): Published clients can request branch
    // deletion. Reject it explicitly so they do not report unperformed cleanup
    // as success; remove the field when v1.7.1 clients are unsupported.
    if (body.deleteBranch) {
      throw buildErrorResponse(request, 422, "branch cleanup is no longer supported");
    }
    final cleanupResult = await _sessionDeletionService.deleteSession(
      sessionId: sessionId,
      deleteWorktree: body.deleteWorktree,
      force: body.force,
    );
    if (cleanupResult case CleanupRejected(:final rejection)) {
      // IMPORTANT: Do not change this response structure — the mobile app
      // parses the 409 body as SessionCleanupRejection JSON.
      throw buildJsonErrorResponse(request, 409, rejection.toJson());
    }

    return const SuccessEmptyResponse();
  }
}
