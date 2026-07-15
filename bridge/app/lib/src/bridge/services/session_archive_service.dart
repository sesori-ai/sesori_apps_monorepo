import "dart:async";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../repositories/filesystem_repository.dart";
import "../repositories/models/stored_session.dart";
import "../repositories/session_repository.dart";
import "session_cleanup_service.dart";
import "worktree_service.dart";

class SessionArchiveConflictException implements Exception {
  final SessionCleanupRejection rejection;

  SessionArchiveConflictException({required this.rejection});
}

/// Result of an archive-status update: the resulting [session] and whether the
/// archive state actually changed (false for a no-op transition, e.g.
/// archiving an already-archived session).
class ArchiveStatusUpdate {
  final Session session;
  final bool changed;

  /// The STORED project id the session row is keyed by. For dedicated-worktree
  /// sessions this can differ from `session.projectID` (the enriched plugin
  /// session may report the worktree directory), so unseen emits must use this
  /// to update the correct project's tracker bucket.
  final String projectId;

  ArchiveStatusUpdate({required this.session, required this.changed, required this.projectId});
}

class SessionNotFoundException implements Exception {}

class SessionInitializationException implements Exception {}

class SessionArchiveService {
  final WorktreeService _worktreeService;
  final SessionRepository _sessionRepository;
  final SessionCleanupService _sessionCleanupService;
  final FilesystemRepository _filesystemRepository;

  SessionArchiveService({
    required WorktreeService worktreeService,
    required SessionRepository sessionRepository,
    required SessionCleanupService sessionCleanupService,
    required FilesystemRepository filesystemRepository,
  }) : _worktreeService = worktreeService,
       _sessionRepository = sessionRepository,
       _sessionCleanupService = sessionCleanupService,
       _filesystemRepository = filesystemRepository;

  Future<ArchiveStatusUpdate> updateArchiveStatus({
    required String sessionId,
    required bool archived,
    required bool deleteWorktree,
    required bool deleteBranch,
    required bool force,
  }) async {
    final storedSession = await _getStoredSession(sessionId: sessionId);
    final wasArchived = storedSession.archivedAt != null;
    final session = archived
        ? await _doArchive(
            storedSession: storedSession,
            deleteWorktree: deleteWorktree,
            deleteBranch: deleteBranch,
            force: force,
          )
        : await _doUnarchive(storedSession: storedSession);
    return ArchiveStatusUpdate(
      session: session,
      changed: wasArchived != archived,
      projectId: storedSession.projectId,
    );
  }

  Future<StoredSession> _getStoredSession({required String sessionId}) async {
    if (await _sessionRepository.getStoredSession(sessionId: sessionId) case final storedSession?) {
      return storedSession;
    }
    final projectId = await _sessionRepository.findProjectIdForSession(sessionId: sessionId);
    if (projectId == null) {
      throw SessionNotFoundException();
    }
    await _sessionRepository.createStoredSessionPlaceholder(
      sessionId: sessionId,
      projectId: projectId,
      isDedicated: true,
      createdAt: DateTime.now().millisecondsSinceEpoch,
      worktreePath: null,
      branchName: null,
      baseBranch: null,
      baseCommit: null,
    );
    final initialized = await _sessionRepository.getStoredSession(sessionId: sessionId);
    if (initialized == null) {
      throw SessionInitializationException();
    }
    return initialized;
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
    if (await _sessionRepository.getSessionForProject(
          projectId: storedSession.projectId,
          sessionId: storedSession.id,
        ) ==
        null) {
      throw SessionNotFoundException();
    }
    await _sessionRepository.archiveStoredSession(
      sessionId: storedSession.id,
      archivedAt: archivedAt,
    );
    unawaited(
      _sessionRepository.notifySessionArchived(sessionId: storedSession.id).catchError((
        Object error,
        StackTrace stackTrace,
      ) {
        Log.w("[archive] failed to notify plugin for session ${storedSession.id}", error, stackTrace);
      }),
    );
    final session = await _sessionRepository.getSessionForProject(
      projectId: storedSession.projectId,
      sessionId: storedSession.id,
    );
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
    final cleanupResult = await _sessionCleanupService.cleanup(
      sessionId: storedSession.id,
      deleteWorktree: deleteWorktree,
      deleteBranch: deleteBranch,
      force: force,
    );
    if (cleanupResult case CleanupRejected(:final rejection)) {
      throw SessionArchiveConflictException(rejection: rejection);
    }
  }

  Future<Session> _doUnarchive({required StoredSession storedSession}) async {
    await _sessionRepository.unarchiveStoredSession(sessionId: storedSession.id);
    if (storedSession case StoredSession(
      isDedicated: true,
      :final projectId,
      worktreePath: final worktreePath?,
      branchName: final branchName?,
    )) {
      final hasWorktreeOnDisk = _filesystemRepository.directoryExists(path: worktreePath);
      if (!hasWorktreeOnDisk) {
        final restoreBaseBranch = await _resolveRestoreBaseBranch(
          projectId: projectId,
          storedBaseBranch: storedSession.baseBranch,
        );
        await _worktreeService.restoreWorktree(
          projectId: projectId,
          worktreePath: worktreePath,
          branchName: branchName,
          baseBranch: restoreBaseBranch,
          baseCommit: storedSession.baseCommit?.normalize(),
        );
      }
    }
    final session = await _sessionRepository.getSessionForProject(
      projectId: storedSession.projectId,
      sessionId: storedSession.id,
    );
    if (session == null) {
      throw SessionNotFoundException();
    }
    return session;
  }

  Future<String> _resolveRestoreBaseBranch({
    required String projectId,
    required String? storedBaseBranch,
  }) async {
    if (storedBaseBranch case final baseBranch?) {
      return baseBranch;
    }
    final resolved = await _worktreeService.resolveBaseBranchAndCommit(projectId: projectId);
    if (resolved == null) {
      throw SessionInitializationException();
    }
    return resolved.baseBranch;
  }
}
