import "package:sesori_shared/sesori_shared.dart";

import "../services/session_archive_status_service.dart";
import "request_handler.dart";

/// Handles `PATCH /session/update/archive` — updates archive status for a session.
class UpdateSessionArchiveStatusHandler extends BodyRequestHandler<UpdateSessionArchiveRequest, Session> {
  final SessionArchiveStatusService _archiveStatusService;

  UpdateSessionArchiveStatusHandler({
    required SessionArchiveStatusService archiveStatusService,
  }) : _archiveStatusService = archiveStatusService,
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

    return _archiveStatusService.updateArchiveStatus(
      requestId: request.id,
      sessionId: sessionId,
      archived: body.archived,
      deleteWorktree: body.deleteWorktree,
      deleteBranch: body.deleteBranch,
      force: body.force,
    );
  }
}
