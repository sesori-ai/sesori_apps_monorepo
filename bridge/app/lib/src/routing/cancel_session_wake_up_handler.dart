import "package:sesori_shared/sesori_shared.dart";

import "../services/session_view_service.dart";
import "../services/session_wake_up_service.dart";
import "request_handler.dart";

/// Handles `POST /session/wake-up/cancel` — the user cancels one of a root
/// session's wake-ups, repeating ones included, and gets the updated session
/// back. A wake-up that already fired or was cancelled needs nothing more; a
/// missing session answers not found.
class CancelSessionWakeUpHandler({
  required final SessionWakeUpService _wakeUps,
  required final SessionViewService _sessionViews,
}) extends BodyRequestHandler<CancelSessionWakeUpRequest, Session> {
  this : super(method: HttpMethod.post, path: "/session/wake-up/cancel", fromJson: CancelSessionWakeUpRequest.fromJson);

  @override
  Future<Session> handle({
    required RelayRequest request,
    required CancelSessionWakeUpRequest body,
  }) async {
    requireNonEmpty(request: request, value: body.sessionId, label: "session id");
    requireNonEmpty(request: request, value: body.wakeUpId, label: "wake-up id");
    // Every result answers with the session as it is now: a wake-up not found
    // is already gone, and a gone session makes the read answer not found.
    await _wakeUps.cancel(sessionId: body.sessionId, wakeUpId: body.wakeUpId);
    return await _sessionViews.get(sessionId: body.sessionId);
  }
}
