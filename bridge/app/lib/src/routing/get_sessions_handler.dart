import "package:sesori_shared/sesori_shared.dart";

import "../repositories/session_repository.dart";
import "../services/session_view_service.dart";
import "request_handler.dart";

/// Handles `GET /sessions` — returns sessions for a given project.
///
/// Reads the durable catalog and applies bridge-owned enrichment.
class GetSessionsHandler({
  required final SessionRepository _sessionRepository,
  required final SessionViewService _sessionViews,
}) extends BodyRequestHandler<SessionListRequest, SessionListResponse> {
  this
    : super(
        HttpMethod.post,
        "/sessions",
        fromJson: SessionListRequest.fromJson,
      );

  @override
  Future<SessionListResponse> handle(
    RelayRequest request, {
    required SessionListRequest body,
  }) async {
    final projectId = requireNonEmpty(request: request, value: body.projectId, label: "project id");

    return SessionListResponse(
      items: await _sessionViews.enrichMany(
        sessions: await _sessionRepository.getSessionsForProject(
          projectId: projectId,
          start: body.start,
          limit: body.limit,
          verifiedGithubLogin: null,
        ),
      ),
    );
  }
}
