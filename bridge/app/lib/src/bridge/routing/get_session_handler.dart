import "dart:async";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log;
import "package:sesori_shared/sesori_shared.dart";

import "../repositories/session_repository.dart";
import "../services/pr_sync_service.dart";
import "request_handler.dart";

/// Handles `POST /session/detail` — returns a single enriched session by ID.
class GetSessionHandler({
  required final SessionRepository _sessionRepository,
  required final PrSyncService _prSyncService,
  final Duration _identityVerificationTimeout = const Duration(seconds: 5),
}) extends BodyRequestHandler<SessionIdRequest, Session> {
  this
    : super(
        HttpMethod.post,
        "/session/detail",
        fromJson: SessionIdRequest.fromJson,
      );

  @override
  Future<Session> handle(
    RelayRequest request, {
    required SessionIdRequest body,
    required Map<String, String> pathParams,
    required Map<String, String> queryParams,
    required String? fragment,
  }) async {
    final sessionId = body.sessionId;
    if (sessionId.isEmpty) {
      throw buildErrorResponse(request, 400, "empty session id");
    }

    final projectId = await _sessionRepository.findProjectIdForSession(sessionId: sessionId);
    if (projectId == null) {
      throw buildErrorResponse(request, 404, "session not found");
    }

    final verifiedGithubLogin = await _prSyncService.verifyGithubIdentity().timeout(
      _identityVerificationTimeout,
      onTimeout: () {
        final error = TimeoutException(
          "GitHub identity verification exceeded ${_identityVerificationTimeout.inSeconds}s",
          _identityVerificationTimeout,
        );
        Log.w(
          "Session detail identity verification timed out; returning PR-free data",
          error,
          StackTrace.current,
        );
        return null;
      },
    );
    final session = await _sessionRepository.getSessionForProject(
      projectId: projectId,
      sessionId: sessionId,
      verifiedGithubLogin: verifiedGithubLogin,
    );
    if (session == null) {
      throw buildErrorResponse(request, 404, "session not found");
    }

    return session;
  }
}
