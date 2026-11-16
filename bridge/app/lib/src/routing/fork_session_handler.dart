import "package:sesori_shared/sesori_shared.dart";

import "../services/session_fork_service.dart";
import "request_handler.dart";

/// Handles `POST /session/fork` — forks a session at a turn boundary into a
/// new session in the same directory or worktree, and answers the new
/// session. Refusals answer `SessionBranchErrorResponse`.
class ForkSessionHandler({required final SessionForkService _sessionForkService})
    extends BodyRequestHandler<ForkSessionRequest, Session> {
  this
    : super(
        method: HttpMethod.post,
        path: "/session/fork",
        fromJson: ForkSessionRequest.fromJson,
      );

  @override
  Future<Session> handle({
    required RelayRequest request,
    required ForkSessionRequest body,
  }) async {
    final sessionId = requireNonEmpty(request: request, value: body.sessionId, label: "session id");
    final point = body.point;
    if (point case ForkPointAfterMessage(:final messageId) || ForkPointBeforeMessage(:final messageId)) {
      requireNonEmpty(request: request, value: messageId, label: "message id");
    }
    return await _sessionForkService.forkSession(
      sessionId: sessionId,
      point: point,
      recreateFromBase: body.recreateFromBase,
    );
  }
}
