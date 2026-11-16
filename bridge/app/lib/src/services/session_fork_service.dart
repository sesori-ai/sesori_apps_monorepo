import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log, PluginBranchPointUnavailableException;
import "package:sesori_shared/sesori_shared.dart";

import "../repositories/models/session_operation.dart";
import "../repositories/session_repository.dart";
import "chat_history_service.dart";
import "session_branch_refused_exception.dart";
import "session_operation_dispatcher.dart";
import "session_view_service.dart";

/// Forks a root session at a turn boundary into a new root session in the
/// same directory or worktree. The origin is only read, so an archived one
/// can be forked too.
class SessionForkService({
  required final SessionRepository _sessionRepository,
  required final ChatHistoryService _chatHistory,
  required final SessionViewService _views,
  required final SessionOperationDispatcher _dispatcher,
}) {
  /// Suffix of a fork's title, after its origin's displayed title. Written by
  /// the bridge like any stored title, so it is not localised.
  static const forkTitleSuffix = " (fork)";

  /// Forks [sessionId] at [point] and returns the new session. Refusals are
  /// [SessionBranchRefusedException]s.
  Future<Session> forkSession({required String sessionId, required ForkPoint point}) async {
    final fork = await _dispatcher.dispatch(
      sessionId: sessionId,
      operation: SessionOperation.forkSession,
      body: () => _createFork(sessionId: sessionId, point: point),
    );
    // Off the origin's lane: the fork is its own session. Also for a fork that
    // kept nothing: its store then knows it is empty, so its first prompt
    // carries the worktree context a new session's does.
    try {
      await _chatHistory.backfillSession(sessionId: fork.id);
    } on Object catch (error, stackTrace) {
      // The fork exists; opening it backfills again.
      Log.w("Could not backfill the history of fork ${fork.id} of session $sessionId", error, stackTrace);
    }
    return await _views.enrich(session: fork);
  }

  Future<Session> _createFork({required String sessionId, required ForkPoint point}) async {
    final origin = await _views.get(sessionId: sessionId);
    // The fork runs in the origin's stored directory. An archived origin's
    // dedicated worktree may have been removed at archive, which this does
    // not check: its fork would point at a missing worktree.
    final boundary = await _chatHistory.forkBoundary(
      sessionId: sessionId,
      point: point,
      running: await _sessionRepository.isSessionRunning(sessionId: sessionId),
    );
    final String? throughMessageId;
    switch (boundary) {
      case ForkBoundaryThroughMessage(:final messageId):
        throughMessageId = messageId;
      case ForkBoundaryEmpty():
        throughMessageId = null;
      case ForkBoundaryNothingToFork():
        throw _refusal(code: SessionBranchErrorCode.nothingToFork);
      case ForkBoundaryTurnRunning():
        throw _refusal(code: SessionBranchErrorCode.sessionBusy);
      case ForkBoundaryNotBranchPoint():
        throw _refusal(code: SessionBranchErrorCode.branchPointUnavailable);
    }
    final originTitle = origin.title;
    final Session fork;
    try {
      fork = await _sessionRepository.forkSession(
        originSessionId: sessionId,
        throughMessageId: throughMessageId,
        // An untitled origin's fork stays untitled unless its harness names it.
        title: originTitle == null ? null : "$originTitle$forkTitleSuffix",
        forkedFromTitle: originTitle,
      );
    } on PluginBranchPointUnavailableException catch (error, stackTrace) {
      // Also how a harness that pruned an archived origin's transcript
      // answers.
      throw SessionBranchRefusedException(
        code: SessionBranchErrorCode.branchPointUnavailable,
        message: error.userFacingReason,
        cause: error,
        causeStackTrace: stackTrace,
      );
    }
    return fork;
  }

  static SessionBranchRefusedException _refusal({required SessionBranchErrorCode code}) =>
      SessionBranchRefusedException(code: code, message: null, cause: null, causeStackTrace: null);
}
