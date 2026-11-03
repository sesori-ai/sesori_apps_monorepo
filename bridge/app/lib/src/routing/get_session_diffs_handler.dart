import "package:sesori_shared/sesori_shared.dart";

import "../services/session_diff_service.dart";
import "request_handler.dart";

/// Returns file diffs for a session's worktree via bridge-side `git diff`.
class GetSessionDiffsHandler({
  required final SessionDiffService _sessionDiffService,
}) extends BodyRequestHandler<SessionIdRequest, SessionDiffsResponse> {
  this
    : super(
        method: HttpMethod.post,
        path: "/session/diffs",
        fromJson: SessionIdRequest.fromJson,
      );

  @override
  Future<SessionDiffsResponse> handle({
    required RelayRequest request,
    required SessionIdRequest body,
  }) async {
    try {
      return SessionDiffsResponse(
        diffs: await _sessionDiffService.getDiffs(sessionId: body.sessionId),
      );
    } on SessionDiffSessionNotFoundException {
      throw buildErrorResponse(request: request, status: 404, message: "session not found: ${body.sessionId}");
    } on BaseBranchUnreachableException catch (error) {
      throw buildErrorResponse(request: request, status: 422, message: error.message);
    } on GitDiffQueryException catch (error) {
      throw buildErrorResponse(request: request, status: 500, message: error.message);
    }
  }
}
