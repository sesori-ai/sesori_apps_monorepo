import "package:sesori_shared/sesori_shared.dart";

import "../repositories/models/session_page_cursor.dart";
import "../repositories/session_repository.dart";
import "../services/session_view_service.dart";
import "request_handler.dart";

/// Handles `POST /sessions/page` — one page of root sessions across the
/// visible projects, newest first, with the counts behind each chip.
///
/// An unknown or hidden project lists nothing rather than answering 404, so a
/// 404 from this route always means a bridge that predates it.
class GetSessionPageHandler({
  required final SessionRepository _sessionRepository,
  required final SessionViewService _sessionViews,
}) extends BodyRequestHandler<SessionPageRequest, SessionPageResponse> {
  static const int maxLimit = 1000;

  this
    : super(
        HttpMethod.post,
        "/sessions/page",
        fromJson: SessionPageRequest.fromJson,
      );

  @override
  Future<SessionPageResponse> handle(
    RelayRequest request, {
    required SessionPageRequest body,
  }) async {
    if (body.limit < 0 || body.limit > maxLimit) {
      throw buildErrorResponse(request, 400, "limit must be between 0 and $maxLimit");
    }
    if (body.projectId case final projectId?) {
      requireNonEmpty(request: request, value: projectId, label: "project id");
    }
    if (body.query case final query? when searchWords(query: query).isEmpty) {
      throw buildErrorResponse(request, 400, "blank query");
    }
    final cursor = switch (body.cursor) {
      null => null,
      final encoded =>
        SessionPageCursor.tryParse(encoded: encoded) ?? (throw buildErrorResponse(request, 400, "invalid cursor")),
    };

    final page = await _sessionRepository.getSessionPage(
      mode: body.mode,
      projectId: body.projectId,
      query: body.query,
      filter: body.filter,
      cursor: cursor,
      limit: body.limit,
    );
    return SessionPageResponse(
      items: await _sessionViews.enrichMany(sessions: page.items),
      nextCursor: page.nextCursor?.encode(),
      counts: page.counts,
    );
  }
}
