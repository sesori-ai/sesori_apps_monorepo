import "dart:async";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log;
import "package:sesori_shared/sesori_shared.dart";

import "../repositories/session_repository.dart";
import "../services/pr_sync_service.dart";
import "request_handler.dart";

/// Handles `GET /sessions` — returns sessions for a given project.
///
/// Reads the durable catalog and applies bridge-owned enrichment.
class GetSessionsHandler extends BodyRequestHandler<SessionListRequest, SessionListResponse> {
  static const _maximumFallbackReserve = Duration(milliseconds: 100);

  final SessionRepository _sessionRepository;
  final PrSyncService _prSyncService;
  final Duration _prRefreshTimeout;

  GetSessionsHandler({
    required SessionRepository sessionRepository,
    required PrSyncService prSyncService,
    Duration prRefreshTimeout = const Duration(seconds: 5),
  }) : _sessionRepository = sessionRepository,
       _prSyncService = prSyncService,
       _prRefreshTimeout = prRefreshTimeout,
       super(
         HttpMethod.post,
         "/sessions",
         fromJson: SessionListRequest.fromJson,
       );

  @override
  Future<SessionListResponse> handle(
    RelayRequest request, {
    required SessionListRequest body,
    required Map<String, String> pathParams,
    required Map<String, String> queryParams,
    required String? fragment,
  }) async {
    final projectId = body.projectId;
    if (projectId.isEmpty) {
      throw buildErrorResponse(
        request,
        400,
        "missing project id in body",
      );
    }

    final start = body.start;
    final limit = body.limit;

    final sessionsWithoutPullRequestData = await _sessionRepository.getSessionsForProject(
      projectId: projectId,
      start: start,
      limit: limit,
      verifiedGithubLogin: null,
    );
    final timeoutStopwatch = Stopwatch()..start();
    final halfRefreshTimeout = Duration(microseconds: _prRefreshTimeout.inMicroseconds ~/ 2);
    final fallbackReserve = halfRefreshTimeout.compareTo(_maximumFallbackReserve) < 0
        ? halfRefreshTimeout
        : _maximumFallbackReserve;
    final mainDeadline = _prRefreshTimeout - fallbackReserve;

    try {
      return await _readIdentityGatedPullRequestData(
        projectId: projectId,
        sessionsWithoutPullRequestData: sessionsWithoutPullRequestData,
        waitForPrData: body.waitForPrData,
      ).timeout(mainDeadline);
    } on _PrRefreshFailedException {
      return _buildPrFreeFallbackResponse(
        sessionsWithoutPullRequestData: sessionsWithoutPullRequestData,
        timeoutStopwatch: timeoutStopwatch,
      );
    } on Object catch (error, stackTrace) {
      Log.w(
        "PR identity-gated read or refresh work failed after waiting up to "
        "${_prRefreshTimeout.inSeconds}s — returning sessions without cached PR data",
        error,
        stackTrace,
      );
      return _buildPrFreeFallbackResponse(
        sessionsWithoutPullRequestData: sessionsWithoutPullRequestData,
        timeoutStopwatch: timeoutStopwatch,
      );
    }
  }

  Future<SessionListResponse> _readIdentityGatedPullRequestData({
    required String projectId,
    required List<Session> sessionsWithoutPullRequestData,
    required bool waitForPrData,
  }) async {
    final prRefreshFuture = _triggerPrRefresh(
      projectId: projectId,
      refreshPolicy: waitForPrData ? PrRefreshPolicy.explicit : PrRefreshPolicy.background,
    );
    var sessions = sessionsWithoutPullRequestData;
    final verifiedGithubLogin = await _prSyncService.verifyGithubIdentity();
    try {
      sessions = await _sessionRepository.enrichSessions(
        sessions: sessions,
        verifiedGithubLogin: verifiedGithubLogin,
      );
    } on Object catch (error, stackTrace) {
      Log.w("GetSessionsHandler: post-publication enrichment failed", error, stackTrace);
    }

    if (!waitForPrData) {
      // COMPATIBILITY 2026-08-01 (v1.6.1): Released clients rely on the
      // non-waiting request to trigger background PR refresh. Remove this path
      // only after those client versions are no longer supported.
      unawaited(prRefreshFuture);
      return SessionListResponse(items: sessions);
    }

    final refreshOutcome = await prRefreshFuture;
    if (refreshOutcome != PrRefreshOutcome.completed) {
      throw const _PrRefreshFailedException();
    }

    // Refresh succeeded within the shared request deadline. Verify identity
    // again before mapping updated PR/CI metadata from the database.
    final refreshedGithubLogin = await _prSyncService.verifyGithubIdentity();
    final enrichedSessions = await _sessionRepository.enrichSessions(
      sessions: sessions,
      verifiedGithubLogin: refreshedGithubLogin,
    );
    return SessionListResponse(items: enrichedSessions);
  }

  Future<SessionListResponse> _buildPrFreeFallbackResponse({
    required List<Session> sessionsWithoutPullRequestData,
    required Stopwatch timeoutStopwatch,
  }) async {
    final fallbackBudget = _remainingBudget(
      timeoutStopwatch: timeoutStopwatch,
      deadline: _prRefreshTimeout,
    );
    if (fallbackBudget == Duration.zero) {
      return SessionListResponse(items: sessionsWithoutPullRequestData);
    }
    return SessionListResponse(
      items: await _reEnrichWithoutPullRequestData(
        sessionsWithoutPullRequestData: sessionsWithoutPullRequestData,
        timeout: fallbackBudget,
      ),
    );
  }

  Future<List<Session>> _reEnrichWithoutPullRequestData({
    required List<Session> sessionsWithoutPullRequestData,
    required Duration timeout,
  }) async {
    try {
      return await _sessionRepository
          .enrichSessions(
            sessions: sessionsWithoutPullRequestData,
            verifiedGithubLogin: null,
          )
          .timeout(timeout);
    } on Object catch (error, stackTrace) {
      Log.w(
        "GetSessionsHandler: PR-free fallback enrichment failed; returning the original snapshot",
        error,
        stackTrace,
      );
      return sessionsWithoutPullRequestData;
    }
  }

  Duration _remainingBudget({
    required Stopwatch timeoutStopwatch,
    required Duration deadline,
  }) {
    final remainingMicroseconds = deadline.inMicroseconds - timeoutStopwatch.elapsedMicroseconds;
    if (remainingMicroseconds <= 0) return Duration.zero;
    return Duration(microseconds: remainingMicroseconds);
  }

  Future<PrRefreshOutcome> _triggerPrRefresh({
    required String projectId,
    required PrRefreshPolicy refreshPolicy,
  }) async {
    try {
      return await _prSyncService.triggerRefresh(
        projectIds: {projectId},
        refreshPolicy: refreshPolicy,
      );
    } on Object catch (e, st) {
      Log.w("[GetSessionsHandler] PR refresh trigger failed", e, st);
      return PrRefreshOutcome.failed;
    }
  }
}

final class _PrRefreshFailedException implements Exception {
  const _PrRefreshFailedException();
}
