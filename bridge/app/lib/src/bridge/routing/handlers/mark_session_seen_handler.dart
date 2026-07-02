import "package:sesori_shared/sesori_shared.dart";

import "../../services/session_unseen_service.dart";
import "../request_handler.dart";

/// Handles `POST /session/seen` — explicit "Mark as Read" ([read] == true) /
/// "Mark as Unread" ([read] == false) for a session. Persists the change and
/// lets the unseen service emit the SSE update that syncs every client.
class MarkSessionSeenHandler extends BodyRequestHandler<MarkSessionSeenRequest, SuccessEmptyResponse> {
  final SessionUnseenService _sessionUnseenService;

  MarkSessionSeenHandler({required SessionUnseenService sessionUnseenService})
    : _sessionUnseenService = sessionUnseenService,
      super(HttpMethod.post, "/session/seen", fromJson: MarkSessionSeenRequest.fromJson);

  @override
  Future<SuccessEmptyResponse> handle(
    RelayRequest request, {
    required MarkSessionSeenRequest body,
    required Map<String, String> pathParams,
    required Map<String, String> queryParams,
    required String? fragment,
  }) async {
    if (body.sessionId.isEmpty) {
      throw buildErrorResponse(request, 400, "empty session id");
    }
    // Normalize an empty/blank client-supplied project id to null so a malformed
    // value can't drive a missing-row aggregate recompute against a bogus
    // project. A null id simply skips the authoritative clear.
    final projectId = body.projectId?.trim().isEmpty ?? true ? null : body.projectId;
    if (body.read) {
      await _sessionUnseenService.markRead(sessionId: body.sessionId, projectId: projectId);
    } else {
      try {
        await _sessionUnseenService.markUnread(sessionId: body.sessionId, projectId: projectId);
      } on SessionUnseenRowMissingException {
        // The service already emitted an authoritative clear; the non-2xx tells
        // the requesting client to roll back its optimistic unread.
        throw buildErrorResponse(request, 404, "session not found");
      }
    }
    return const SuccessEmptyResponse();
  }
}
