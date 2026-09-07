import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log;
import "package:sesori_shared/sesori_shared.dart";

import "../repositories/filesystem_repository.dart";
import "../repositories/models/session_operation.dart";
import "../repositories/models/stored_session.dart";
import "../repositories/session_repository.dart";
import "archived_session_validator.dart";
import "chat_history_service.dart";
import "session_cleanup_result.dart";
import "session_operation_dispatcher.dart";
import "worktree_service.dart";

enum SessionCleanupOperation() { removeWorktree }

class SessionCleanupFailedException({
    required final String sessionId,
    required final SessionCleanupOperation operation,
  }) implements Exception {
  @override
  String toString() => "session cleanup failed for $sessionId while ${operation.name}";
}

class SessionArchiveConflictException({required final SessionCleanupRejection rejection}) implements Exception;

class ArchiveStatusUpdate({
  required final Session session,
  required final bool changed,
  /// The stored project id the session row is keyed by. A dedicated-worktree
  /// session can report its worktree directory as the enriched project id.
  required final String projectId,
});

class SessionNotFoundException() implements Exception;

class SessionLifecycleService({
    required final WorktreeService _worktreeService,
    required final SessionRepository _sessionRepository,
    required final FilesystemRepository _filesystemRepository,
    required final SessionOperationDispatcher _sessionOperationDispatcher,
    required final ChatHistoryService _chatHistoryService,
    required final ArchivedSessionValidator _archivedSessionValidator,
  }) {

  /// Runs cleanup inside a session-family operation already reserved by the
  /// archive or deletion workflow.
  ///
  /// Worktree removal is git-only, so this path deliberately skips the
  /// routability requirement: deleting a session must still work when its
  /// backend is uninstalled or cannot start.
  Future<CleanupResult> cleanupAlreadyReserved({
    required String sessionId,
    required bool deleteWorktree,
    required bool force,
  }) async {
    final storedSession = await _sessionRepository.requireStoredSession(
      sessionId: sessionId,
      operation: SessionOperation.cleanupSession,
    );
    final worktreePath = storedSession.worktreePath;
    if (!deleteWorktree || worktreePath == null) {
      return CleanupSuccess();
    }

    final projectId = storedSession.projectId;

    // Shared-worktree cleanup is forceable so the user can resolve a stalemate
    // when multiple sessions point at the same worktree.
    if (!force) {
      final hasSharing = await _sessionRepository.hasOtherActiveSessionsSharing(
        sessionId: sessionId,
        projectId: projectId,
        worktreePath: worktreePath,
        branchName: null,
      );
      if (hasSharing) {
        return CleanupRejected(
          rejection: const SessionCleanupRejection(
            issues: [CleanupIssue.sharedWorktree()],
          ),
        );
      }
    }

    if (!force) {
      final safety = await _worktreeService.checkWorktreeSafety(
        worktreePath: worktreePath,
      );
      if (safety case WorktreeUnsafe(:final issues)) {
        return CleanupRejected(
          rejection: SessionCleanupRejection(
            issues: _mapSafetyIssues(issues: issues),
          ),
        );
      }
    }

    final removed = await _worktreeService.removeWorktree(
      pluginId: storedSession.pluginId,
      projectId: projectId,
      worktreePath: worktreePath,
      force: force,
    );
    if (!removed && _filesystemRepository.classifyPath(path: worktreePath) != FilesystemEntityKind.notFound) {
      throw SessionCleanupFailedException(
        sessionId: sessionId,
        operation: SessionCleanupOperation.removeWorktree,
      );
    }

    return CleanupSuccess();
  }

  Future<ArchiveStatusUpdate> updateArchiveStatus({
    required String sessionId,
    required bool archived,
    required bool deleteWorktree,
    required bool force,
  }) {
    return _sessionOperationDispatcher.dispatch(
      sessionId: sessionId,
      operation: SessionOperation.updateSessionArchiveStatus,
      body: () => _updateArchiveStatusAlreadyReserved(
        sessionId: sessionId,
        archived: archived,
        deleteWorktree: deleteWorktree,
        force: force,
      ),
    );
  }

  Future<ArchiveStatusUpdate> _updateArchiveStatusAlreadyReserved({
    required String sessionId,
    required bool archived,
    required bool deleteWorktree,
    required bool force,
  }) async {
    // COMPATIBILITY 2026-08-07 (v1.7.0): published apps render Unarchive from
    // time.archived alone, so the request shape still accepts `archived: false`
    // and answers with an explicit rejection; remove tolerance when out of
    // support.
    if (!archived) {
      return await _refuseUnarchive(sessionId: sessionId);
    }
    final storedSession = await _getStoredSession(sessionId: sessionId);
    return ArchiveStatusUpdate(
      session: await _doArchive(
        storedSession: storedSession,
        deleteWorktree: deleteWorktree,
        force: force,
      ),
      changed: storedSession.archivedAt == null,
      projectId: storedSession.projectId,
    );
  }

  /// Archiving is permanent. `archived: false` is refused for an archived
  /// session and stays an unchanged no-op for one that is not.
  ///
  /// Neither answer needs the backend, so this path deliberately skips the
  /// routability requirement: an archived session must still be refused with
  /// the archived rejection when its plugin is stopped.
  Future<ArchiveStatusUpdate> _refuseUnarchive({required String sessionId}) async {
    final storedSession = await _archivedSessionValidator.requireNotArchived(sessionId: sessionId);
    final session = await _sessionRepository.getCatalogSession(sessionId: sessionId);
    if (storedSession == null || session == null) {
      throw SessionNotFoundException();
    }
    return ArchiveStatusUpdate(
      session: session,
      changed: false,
      projectId: storedSession.projectId,
    );
  }

  Future<StoredSession> _getStoredSession({required String sessionId}) async {
    return await _sessionRepository.requireRoutableStoredSession(
      sessionId: sessionId,
      operation: SessionOperation.updateSessionArchiveStatus,
    );
  }

  Future<Session> _doArchive({
    required StoredSession storedSession,
    required bool deleteWorktree,
    required bool force,
  }) async {
    final archivedAt = DateTime.now().millisecondsSinceEpoch;
    // Export first, before worktree cleanup: bringing the store current may
    // need the session's worktree, since directory-scoped backends replay from
    // it. Exporting afterwards could silently archive a truncated transcript.
    // A cleanup rejection after a successful export leaves only an orphan
    // audit file, which the next attempt overwrites.
    await _exportHistory(storedSession: storedSession, archivedAt: archivedAt);
    await _cleanupIfNeeded(
      storedSession: storedSession,
      deleteWorktree: deleteWorktree,
      force: force,
    );
    await _sessionRepository.archiveStoredSession(
      sessionId: storedSession.id,
      archivedAt: archivedAt,
    );
    // After the flip: the audit file is durable, so the live rows are now
    // redundant. Shared attachment bytes remain outside this lifecycle. A
    // failure here leaves duplicate rows that startup reconciliation removes.
    try {
      await _chatHistoryService.purgeSessionHistory(sessionId: storedSession.id);
    } on Object catch (error, stackTrace) {
      Log.w(
        "[archive] failed to purge stored history for session ${storedSession.id}; "
        "the archive succeeded and startup reconciliation will retry",
        error,
        stackTrace,
      );
    }
    try {
      await _sessionRepository.notifySessionArchived(sessionId: storedSession.id);
    } on Object catch (error, stackTrace) {
      Log.w("[archive] failed to notify plugin for session ${storedSession.id}", error, stackTrace);
    }
    final session = await _sessionRepository.getCatalogSession(sessionId: storedSession.id);
    if (session == null) {
      throw SessionNotFoundException();
    }
    return session;
  }

  /// Only a storage-level write failure fails the archive: the session stays
  /// active with its live store intact rather than losing its transcript.
  Future<void> _exportHistory({
    required StoredSession storedSession,
    required int archivedAt,
  }) async {
    final session = await _sessionRepository.getCatalogSession(sessionId: storedSession.id);
    await _chatHistoryService.exportSessionHistory(
      session: storedSession,
      title: session?.title,
      createdAt: session?.time?.created ?? archivedAt,
      updatedAt: session?.time?.updated ?? archivedAt,
      archivedAt: archivedAt,
    );
  }

  Future<void> _cleanupIfNeeded({
    required StoredSession storedSession,
    required bool deleteWorktree,
    required bool force,
  }) async {
    if (!deleteWorktree) {
      return;
    }
    final cleanupResult = await cleanupAlreadyReserved(
      sessionId: storedSession.id,
      deleteWorktree: deleteWorktree,
      force: force,
    );
    if (cleanupResult case CleanupRejected(:final rejection)) {
      throw SessionArchiveConflictException(rejection: rejection);
    }
  }

  List<CleanupIssue> _mapSafetyIssues({required List<SafetyIssue> issues}) {
    return issues
        .map(
          (issue) => switch (issue) {
            UnstagedChanges() => const CleanupIssue.unstagedChanges(),
          },
        )
        .toList();
  }
}
