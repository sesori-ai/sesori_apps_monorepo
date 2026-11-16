import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log, PluginBranchPointUnavailableException;
import "package:sesori_shared/sesori_shared.dart";

import "../repositories/models/session_operation.dart";
import "../repositories/models/stored_session.dart";
import "../repositories/models/worktree_types.dart";
import "../repositories/session_repository.dart";
import "../repositories/worktree_repository.dart";
import "chat_history_service.dart";
import "session_branch_refused_exception.dart";
import "session_operation_dispatcher.dart";
import "session_view_service.dart";

/// Forks a root session at a turn boundary into a new root session in the
/// same directory or worktree. The origin is only read, so an archived one
/// can be forked too; its worktree is recreated when archiving removed it.
class SessionForkService({
  required final SessionRepository _sessionRepository,
  required final ChatHistoryService _chatHistory,
  required final WorktreeRepository _worktrees,
  required final SessionViewService _views,
  required final SessionOperationDispatcher _dispatcher,
}) {
  /// Suffix of a fork's title, after its origin's displayed title. Written by
  /// the bridge like any stored title, so it is not localised.
  static const forkTitleSuffix = " (fork)";

  /// Forks [sessionId] at [point] and returns the new session. Refusals are
  /// [SessionBranchRefusedException]s. [recreateFromBase] lets an archived
  /// origin whose worktree and branch are gone get a new worktree from its
  /// base.
  Future<Session> forkSession({
    required String sessionId,
    required ForkPoint point,
    required bool recreateFromBase,
  }) async {
    final fork = await _dispatcher.dispatch(
      sessionId: sessionId,
      operation: SessionOperation.forkSession,
      body: () => _createFork(sessionId: sessionId, point: point, recreateFromBase: recreateFromBase),
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

  Future<Session> _createFork({
    required String sessionId,
    required ForkPoint point,
    required bool recreateFromBase,
  }) async {
    final origin = await _views.get(sessionId: sessionId);
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
        throw _refusal(code: SessionBranchErrorCode.nothingToFork, message: null);
      case ForkBoundaryTurnRunning():
        throw _refusal(code: SessionBranchErrorCode.sessionBusy, message: null);
      case ForkBoundaryNotBranchPoint():
        throw _refusal(code: SessionBranchErrorCode.branchPointUnavailable, message: null);
    }
    // The fork runs in the origin's stored directory, so it must exist before
    // the harness is asked for anything.
    await _restoreArchivedWorktree(sessionId: sessionId, recreateFromBase: recreateFromBase);
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

  /// Recreates an archived origin's dedicated worktree at its old path when
  /// archiving removed it: the harness session and the agent's remembered
  /// paths still point there. Nothing else counts the archived origin as a
  /// sharer, so the fork's own archive or deletion removes it again.
  Future<void> _restoreArchivedWorktree({required String sessionId, required bool recreateFromBase}) async {
    final origin = await _sessionRepository.requireStoredSession(
      sessionId: sessionId,
      operation: SessionOperation.forkSession,
    );
    if (origin case StoredSession(archivedAt: _?, isDedicated: true, :final worktreePath?)) {
      if (await _worktrees.worktreeExists(worktreePath: worktreePath)) return;
      if (_worktrees.worktreePathExists(worktreePath: worktreePath)) {
        throw _refusal(
          code: SessionBranchErrorCode.refused,
          message: "The folder this session's worktree was in is now used by something else.",
        );
      }
      final recreation = await _worktrees.recreateWorktree(
        projectPath: await _worktrees.resolveProjectPath(projectId: origin.projectId),
        worktreePath: worktreePath,
        branchName: origin.branchName,
        baseBranch: origin.baseBranch,
        baseCommit: origin.baseCommit,
        fromBase: recreateFromBase,
      );
      switch (recreation) {
        case WorktreeRecreated():
          Log.i("Recreated worktree $worktreePath of archived session $sessionId to fork it");
        case WorktreeRecreationBranchMissing():
          throw _refusal(code: SessionBranchErrorCode.worktreeBranchMissing, message: null);
        case WorktreeRecreationFailed():
          throw _refusal(
            code: SessionBranchErrorCode.refused,
            message: "This session's worktree was removed and could not be recreated.",
          );
      }
    }
  }

  static SessionBranchRefusedException _refusal({required SessionBranchErrorCode code, required String? message}) =>
      SessionBranchRefusedException(code: code, message: message, cause: null, causeStackTrace: null);
}
