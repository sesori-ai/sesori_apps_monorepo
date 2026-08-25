import "package:sesori_shared/sesori_shared.dart";

import "../repositories/session_repository.dart";
import "request_handler.dart";

/// Handles `GET /session/status` — returns statuses for sessions.
///
/// Returns statuses for ALL sessions globally — not filtered by session or project.
class GetSessionStatusesHandler({required final SessionRepository _sessionRepository})
    extends GetRequestHandler<SessionStatusResponse> {
  this : super("/session/status");

  @override
  Future<SessionStatusResponse> handle(
    RelayRequest request,
  ) async {
    return await _sessionRepository.getSessionStatuses();
  }
}
