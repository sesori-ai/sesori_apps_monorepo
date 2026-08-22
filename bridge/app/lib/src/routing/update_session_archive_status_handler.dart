import "dart:async";

import "package:sesori_shared/sesori_shared.dart";

import "../services/session_lifecycle_service.dart";
import "../services/session_unseen_service.dart";
import "request_handler.dart";

/// Handles `PATCH /session/update/archive` — updates archive status for a session.
class UpdateSessionArchiveStatusHandler({
  required final SessionLifecycleService _sessionLifecycleService,
  required final SessionUnseenService _sessionUnseenService,
}) extends BodyRequestHandler<UpdateSessionArchiveRequest, Session> {
  this
    : super(
        HttpMethod.patch,
        "/session/update/archive",
        fromJson: UpdateSessionArchiveRequest.fromJson,
      );

  @override
  Future<Session> handle(
    RelayRequest request, {
    required UpdateSessionArchiveRequest body,
  }) async {
    final sessionId = body.sessionId;
    requireNonEmpty(request, sessionId, "session id");
    // COMPATIBILITY 2026-08-13 (v1.7.1): Published clients can request branch
    // deletion. Reject it explicitly so they do not report unperformed cleanup
    // as success; remove the field when v1.7.1 clients are unsupported.
    if (body.deleteBranch) {
      throw buildErrorResponse(request, 422, "branch cleanup is no longer supported");
    }
    try {
      final update = await _sessionLifecycleService.updateArchiveStatus(
        sessionId: sessionId,
        archived: body.archived,
        deleteWorktree: body.deleteWorktree,
        force: body.force,
      );
      final session = update.session;
      // Archive/unarchive flips whether this session contributes to the project
      // aggregate (archived rows are excluded), so emit an unseen change for
      // other connected clients — but only when the archive state actually
      // changed, to avoid churn on no-op transitions. Fire-and-forget; the
      // service serializes/logs.
      if (update.changed) {
        unawaited(
          // Use the STORED project id (update.projectId), not session.projectID:
          // for dedicated-worktree sessions the enriched plugin session can carry
          // the worktree directory, which would update the wrong tracker bucket
          // and leave the original project bold until a REST refresh.
          _sessionUnseenService.notifyExternalChange(sessionId: session.id, projectId: update.projectId),
        );
      }
      return session;
    } on SessionArchiveConflictException catch (e) {
      throw buildJsonErrorResponse(request, 409, e.rejection.toJson());
    } on SessionNotFoundException {
      throw buildErrorResponse(request, 404, "session not found");
    }
  }
}
