import "dart:async";
import "dart:convert";

import "package:sesori_shared/sesori_shared.dart";

import "../services/session_archive_service.dart";
import "request_handler.dart";

/// Handles `PATCH /session/update/archive` — updates archive status for a session.
class UpdateSessionArchiveStatusHandler extends BodyRequestHandler<UpdateSessionArchiveRequest, Session> {
  final SessionArchiveService _sessionArchiveService;

  UpdateSessionArchiveStatusHandler({
    required SessionArchiveService sessionArchiveService,
  }) : _sessionArchiveService = sessionArchiveService,
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
      return await _sessionArchiveService.updateArchiveStatus(
        sessionId: sessionId,
        archived: body.archived,
        deleteWorktree: body.deleteWorktree,
        deleteBranch: body.deleteBranch,
        force: body.force,
      );
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
