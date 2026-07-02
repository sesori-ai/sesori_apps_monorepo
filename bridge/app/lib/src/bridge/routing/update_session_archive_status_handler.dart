import "dart:async";
import "dart:convert";

import "package:sesori_shared/sesori_shared.dart";

import "../services/session_archive_service.dart";
import "../services/session_unseen_service.dart";
import "request_handler.dart";

/// Handles `PATCH /session/update/archive` — updates archive status for a session.
class UpdateSessionArchiveStatusHandler extends BodyRequestHandler<UpdateSessionArchiveRequest, Session> {
  final SessionArchiveService _sessionArchiveService;
  final SessionUnseenService _sessionUnseenService;

  UpdateSessionArchiveStatusHandler({
    required SessionArchiveService sessionArchiveService,
    required SessionUnseenService sessionUnseenService,
  }) : _sessionArchiveService = sessionArchiveService,
       _sessionUnseenService = sessionUnseenService,
       super(
         HttpMethod.patch,
         "/session/update/archive",
         fromJson: UpdateSessionArchiveRequest.fromJson,
       );

  @override
  Future<Session> handle(
    RelayRequest request, {
    required UpdateSessionArchiveRequest body,
    required Map<String, String> pathParams,
    required Map<String, String> queryParams,
    required String? fragment,
  }) async {
    final sessionId = body.sessionId;
    if (sessionId.isEmpty) {
      throw buildErrorResponse(request, 400, "empty session id");
    }
    try {
      final update = await _sessionArchiveService.updateArchiveStatus(
        sessionId: sessionId,
        archived: body.archived,
        deleteWorktree: body.deleteWorktree,
        deleteBranch: body.deleteBranch,
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
      throw RelayResponse(
        id: request.id,
        status: 409,
        headers: {"content-type": "application/json"},
        body: jsonEncode(e.rejection.toJson()),
      );
    } on SessionNotFoundException {
      throw buildErrorResponse(request, 404, "session not found");
    } on SessionInitializationException {
      throw buildErrorResponse(request, 500, "failed to initialize session");
    }
  }
}
