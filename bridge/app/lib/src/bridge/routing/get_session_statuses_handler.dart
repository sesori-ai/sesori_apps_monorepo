import "package:sesori_shared/sesori_shared.dart";

import "../repositories/session_repository.dart";
import "request_handler.dart";

/// Handles `GET /session/status` — returns statuses for sessions.
///
/// Returns statuses for ALL sessions globally — not filtered by session or project.
class GetSessionStatusesHandler({required SessionRepository sessionRepository}) extends GetRequestHandler<SessionStatusResponse> {
  final SessionRepository _sessionRepository;

  this
    : _sessionRepository = sessionRepository,
      super("/session/status");

  @override
  Future<SessionStatusResponse> handle(
    RelayRequest request, {
    required Map<String, String> pathParams,
    required Map<String, String> queryParams,
    required String? fragment,
  }) async {
    return _sessionRepository.getSessionStatuses();
  }
}
