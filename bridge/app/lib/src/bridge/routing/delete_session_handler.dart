import "dart:convert";

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
    required Map<String, String> pathParams,
    required Map<String, String> queryParams,
    required String? fragment,
  }) async {
    final sessionId = body.sessionId;
    if (sessionId.isEmpty) {
      throw buildErrorResponse(request, 400, "empty session id");
    }

    // COMPATIBILITY 2026-08-13 (v1.7.1): Published clients still send
    // deleteBranch. It is intentionally ignored; remove the field from the
    // request model when v1.7.1 clients are unsupported.
    final cleanupResult = await _sessionDeletionService.deleteSession(
      sessionId: sessionId,
      deleteWorktree: body.deleteWorktree,
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
