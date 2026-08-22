import "dart:async";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log;
import "package:sesori_shared/sesori_shared.dart";

import "../repositories/session_repository.dart";
import "../services/pr_sync_service.dart";
import "request_handler.dart";

/// Handles `GET /sessions` — returns sessions for a given project.
///
/// Reads the durable catalog and applies bridge-owned enrichment.
class GetSessionsHandler({
  required final SessionRepository _sessionRepository,
  required final PrSyncService _prSyncService,
  final Duration _prRefreshTimeout = const Duration(seconds: 5),
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
    final prRefreshFuture = _triggerPrRefresh(
      projectId: projectId,
      refreshPolicy: body.waitForPrData ? PrRefreshPolicy.explicit : PrRefreshPolicy.background,
    );

    final List<Session> identityGatedSessions;
    try {
      identityGatedSessions = await _readIdentityGatedPullRequestData(
        sessionsWithoutPullRequestData: sessionsWithoutPullRequestData,
      ).timeout(_prRefreshTimeout);
    } on Object catch (error, stackTrace) {
      unawaited(prRefreshFuture);
      Log.w(
        "PR identity-gated read did not finish within ${_prRefreshTimeout.inSeconds}s — "
        "returning sessions without cached PR data",
        error,
        stackTrace,
      );
      return SessionListResponse(items: sessionsWithoutPullRequestData);
    }

    if (!body.waitForPrData) {
      // COMPATIBILITY 2026-08-01 (v1.6.1): Released clients rely on the
      // non-waiting request to trigger background PR refresh. Remove this path
      // only after those client versions are no longer supported.
      unawaited(prRefreshFuture);
      return SessionListResponse(items: identityGatedSessions);
    }

    return SessionListResponse(
      items: await _awaitRefreshedPullRequestData(
        prRefreshFuture: prRefreshFuture,
        identityGatedSessions: identityGatedSessions,
        deadline: _remainingBudget(timeoutStopwatch: timeoutStopwatch, deadline: _prRefreshTimeout),
      ),
    );
  }

  Future<List<Session>> _readIdentityGatedPullRequestData({
    required List<Session> sessionsWithoutPullRequestData,
  }) async {
    final verifiedGithubLogin = await _prSyncService.verifyGithubIdentity();
    try {
      return await _sessionRepository.enrichSessions(
        sessions: sessionsWithoutPullRequestData,
        verifiedGithubLogin: verifiedGithubLogin,
      );
    } on Object catch (error, stackTrace) {
      Log.w("GetSessionsHandler: post-publication enrichment failed", error, stackTrace);
      return sessionsWithoutPullRequestData;
    }
  }

  /// Waits for the explicit refresh and re-reads PR metadata within [deadline].
  ///
  /// A failed, slow, or unreadable refresh keeps [identityGatedSessions] — the
  /// snapshot this request already read behind a fresh identity check — instead
  /// of downgrading the response to PR-free data. Discarding it would clear the
  /// rendered PR status of every session on an explicit pull-to-refresh.
  Future<List<Session>> _awaitRefreshedPullRequestData({
    required Future<PrRefreshOutcome> prRefreshFuture,
    required List<Session> identityGatedSessions,
    required Duration deadline,
  }) async {
    if (deadline == Duration.zero) {
      unawaited(prRefreshFuture);
      return identityGatedSessions;
    }
    final refreshStopwatch = Stopwatch()..start();
    try {
      if (await prRefreshFuture.timeout(deadline) != PrRefreshOutcome.completed) {
        return identityGatedSessions;
      }
      // Refresh succeeded within the shared request deadline. Verify identity
      // again before mapping updated PR/CI metadata from the database.
      final refreshedGithubLogin = await _prSyncService.verifyGithubIdentity().timeout(
        _remainingBudget(timeoutStopwatch: refreshStopwatch, deadline: deadline),
      );
      return await _sessionRepository
          .enrichSessions(
            sessions: identityGatedSessions,
            verifiedGithubLogin: refreshedGithubLogin,
          )
          .timeout(_remainingBudget(timeoutStopwatch: refreshStopwatch, deadline: deadline));
    } on Object catch (error, stackTrace) {
      Log.w(
        "PR refresh did not produce a readable snapshot within "
        "${_prRefreshTimeout.inSeconds}s — keeping the identity-gated PR data already read",
        error,
        stackTrace,
      );
      return identityGatedSessions;
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
