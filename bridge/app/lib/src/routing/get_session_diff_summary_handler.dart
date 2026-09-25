import "package:sesori_shared/sesori_shared.dart";

import "../services/session_diff_service.dart";
import "request_handler.dart";

/// Returns a session's line totals for the Changes label, without the files'
/// contents that `/session/diffs` carries.
class GetSessionDiffSummaryHandler({
  required final SessionDiffService _sessionDiffService,
}) extends BodyRequestHandler<SessionIdRequest, SessionDiffSummaryResponse> {
  this
    : super(
        HttpMethod.post,
        "/session/diff-summary",
        fromJson: SessionIdRequest.fromJson,
      );

  @override
  Future<SessionDiffSummaryResponse> handle(
    RelayRequest request, {
    required SessionIdRequest body,
  }) async {
    try {
      final counts = await _sessionDiffService.getSummary(sessionId: body.sessionId);
      return SessionDiffSummaryResponse(additions: counts.additions, deletions: counts.deletions);
    } on SessionDiffSessionNotFoundException {
      // A body, unlike the bare 404 an older bridge returns for this unknown
      // route, lets the app tell a missing session from an unsupported request.
      throw buildJsonErrorResponse(
        request: request,
        status: 404,
        body: const SessionDiffSummaryErrorResponse(code: SessionDiffSummaryErrorCode.sessionNotFound).toJson(),
      );
    } on BaseBranchUnreachableException catch (error) {
      throw buildErrorResponse(request, 422, error.message);
    } on GitDiffQueryException catch (error) {
      throw buildErrorResponse(request, 500, error.message);
    }
  }
}
