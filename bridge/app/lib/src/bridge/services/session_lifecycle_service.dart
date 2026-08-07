import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log;
import "package:sesori_shared/sesori_shared.dart";

import "../repositories/filesystem_repository.dart";
import "../repositories/models/session_operation.dart";
import "../repositories/models/stored_session.dart";
import "../repositories/session_repository.dart";
import "archived_session_validator.dart";
import "session_cleanup_result.dart";
import "session_operation_dispatcher.dart";
import "worktree_service.dart";

enum SessionCleanupOperation { removeWorktree, deleteBranch }

class SessionCleanupFailedException implements Exception {
  final String sessionId;
  final SessionCleanupOperation operation;

  SessionCleanupFailedException({
    required this.sessionId,
    required this.operation,
  });

  @override
  String toString() => "session cleanup failed for $sessionId while ${operation.name}";
}

class SessionArchiveConflictException implements Exception {
  final SessionCleanupRejection rejection;

  SessionArchiveConflictException({required this.rejection});
}

class ArchiveStatusUpdate {
  final Session session;
  final bool changed;

  /// The stored project id the session row is keyed by. A dedicated-worktree
  /// session can report its worktree directory as the enriched project id.
  final String projectId;

  ArchiveStatusUpdate({required this.session, required this.changed, required this.projectId});
}

class SessionNotFoundException implements Exception {}

class SessionLifecycleService {
  final WorktreeService _worktreeService;
  final SessionRepository _sessionRepository;
  final FilesystemRepository _filesystemRepository;
  final SessionOperationDispatcher _sessionOperationDispatcher;
  final ArchivedSessionValidator _archivedSessionValidator;

  SessionLifecycleService({
    required WorktreeService worktreeService,
    required SessionRepository sessionRepository,
    required FilesystemRepository filesystemRepository,
    required SessionOperationDispatcher sessionOperationDispatcher,
    required ArchivedSessionValidator archivedSessionValidator,
  }) : _worktreeService = worktreeService,
       _sessionRepository = sessionRepository,
       _filesystemRepository = filesystemRepository,
       _sessionOperationDispatcher = sessionOperationDispatcher,
       _archivedSessionValidator = archivedSessionValidator;

  /// Runs cleanup inside a session-family operation already reserved by the
  /// archive or deletion workflow.
  Future<CleanupResult> cleanupAlreadyReserved({
    required String sessionId,
    required bool deleteWorktree,
    required bool deleteBranch,
    required bool force,
  }) async {
    final storedSession = await _sessionRepository.requireRoutableStoredSession(
      sessionId: sessionId,
      operation: SessionOperation.cleanupSession,
    );
    final worktreePath = storedSession.worktreePath;
    final branchName = storedSession.branchName;
    if (!(deleteWorktree || deleteBranch) || worktreePath == null || branchName == null) {
      return CleanupSuccess();
    }

    final projectId = storedSession.projectId;

    // Shared-worktree cleanup is forceable so the user can resolve a stalemate
    // when multiple sessions point at the same worktree or branch.
    if (!force) {
      final hasSharing = await _sessionRepository.hasOtherActiveSessionsSharing(
        sessionId: sessionId,
        projectId: projectId,
        worktreePath: deleteWorktree ? worktreePath : null,
        branchName: deleteBranch ? branchName : null,
      );
      if (hasSharing) {
        return CleanupRejected(
          rejection: const SessionCleanupRejection(
            issues: [CleanupIssue.sharedWorktree()],
          ),
        );
      }
    }

    if (deleteWorktree && !force) {
      final safety = await _worktreeService.checkWorktreeSafety(
        worktreePath: worktreePath,
        expectedBranch: branchName,
      );
      if (safety case WorktreeUnsafe(:final issues)) {
        return CleanupRejected(
          rejection: SessionCleanupRejection(
            issues: _mapSafetyIssues(issues: issues),
          ),
        );
      }
    }

    if (deleteWorktree) {
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
    }

    if (deleteBranch) {
      final deleted = await _worktreeService.deleteBranch(
        projectId: projectId,
        branchName: branchName,
        force: deleteWorktree || force,
      );
      if (!deleted &&
          await _worktreeService.branchExists(
            projectId: projectId,
            branchName: branchName,
          )) {
        throw SessionCleanupFailedException(
          sessionId: sessionId,
          operation: SessionCleanupOperation.deleteBranch,
        );
      }
    }

    return CleanupSuccess();
  }

  Future<ArchiveStatusUpdate> updateArchiveStatus({
    required String sessionId,
    required bool archived,
    required bool deleteWorktree,
    required bool deleteBranch,
    required bool force,
  }) {
    return _sessionOperationDispatcher.dispatch(
      sessionId: sessionId,
      operation: SessionOperation.updateSessionArchiveStatus,
      body: () => _updateArchiveStatusAlreadyReserved(
        sessionId: sessionId,
        archived: archived,
        deleteWorktree: deleteWorktree,
        deleteBranch: deleteBranch,
        force: force,
      ),
    );
  }

  Future<ArchiveStatusUpdate> _updateArchiveStatusAlreadyReserved({
    required String sessionId,
    required bool archived,
    required bool deleteWorktree,
    required bool deleteBranch,
    required bool force,
  }) async {
    final storedSession = await _getStoredSession(sessionId: sessionId);
    final wasArchived = storedSession.archivedAt != null;
    // COMPATIBILITY 2026-08-07 (v1.7.0): published apps render Unarchive from
    // time.archived alone, so the request shape still accepts `archived: false`
    // and answers with an explicit rejection; remove tolerance when out of
    // support.
    final session = archived
        ? await _doArchive(
            storedSession: storedSession,
            deleteWorktree: deleteWorktree,
            deleteBranch: deleteBranch,
            force: force,
          )
        : await _refuseUnarchive(storedSession: storedSession);
    return ArchiveStatusUpdate(
      session: session,
      changed: wasArchived != archived,
      projectId: storedSession.projectId,
    );
  }

  /// Archiving is permanent. `archived: false` stays a no-op for a session that
  /// is not archived and is refused for one that is.
  Future<Session> _refuseUnarchive({required StoredSession storedSession}) async {
    await _archivedSessionValidator.requireNotArchived(sessionId: storedSession.id);
    final session = await _sessionRepository.getCatalogSession(sessionId: storedSession.id);
    if (session == null) {
      throw SessionNotFoundException();
    }
    return session;
  }

  Future<StoredSession> _getStoredSession({required String sessionId}) async {
    return _sessionRepository.requireRoutableStoredSession(
      sessionId: sessionId,
      operation: SessionOperation.updateSessionArchiveStatus,
    );
  }

  Future<Session> _doArchive({
    required StoredSession storedSession,
    required bool deleteWorktree,
    required bool deleteBranch,
    required bool force,
  }) async {
    final archivedAt = DateTime.now().millisecondsSinceEpoch;
    await _cleanupIfNeeded(
      storedSession: storedSession,
      deleteWorktree: deleteWorktree,
      deleteBranch: deleteBranch,
      force: force,
    );
    await _sessionRepository.archiveStoredSession(
      sessionId: storedSession.id,
      archivedAt: archivedAt,
    );
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

  Future<void> _cleanupIfNeeded({
    required StoredSession storedSession,
    required bool deleteWorktree,
    required bool deleteBranch,
    required bool force,
  }) async {
    if (!(deleteWorktree || deleteBranch)) {
      return;
    }
    final cleanupResult = await cleanupAlreadyReserved(
      sessionId: storedSession.id,
      deleteWorktree: deleteWorktree,
      deleteBranch: deleteBranch,
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
            BranchMismatch(:final expected, :final actual) => CleanupIssue.branchMismatch(
              expected: expected,
              actual: actual,
            ),
          },
        )
        .toList();
  }
}
