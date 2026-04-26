import "dart:async";
import "dart:io";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../persistence/tables/session_table.dart";
import "../repositories/session_repository.dart";
import "../routing/worktree_cleanup.dart";
import "session_persistence_service.dart";
import "worktree_service.dart";

class SessionArchiveConflictException implements Exception {
  final SessionCleanupRejection rejection;

  SessionArchiveConflictException({required this.rejection});
}

class SessionNotFoundException implements Exception {}

class SessionInitializationException implements Exception {}

class SessionArchiveService {
  final WorktreeService _worktreeService;
  final SessionRepository _sessionRepository;
  final SessionPersistenceService _sessionPersistenceService;

  SessionArchiveService({
    required WorktreeService worktreeService,
    required SessionRepository sessionRepository,
    required SessionPersistenceService sessionPersistenceService,
  }) : _worktreeService = worktreeService,
       _sessionRepository = sessionRepository,
       _sessionPersistenceService = sessionPersistenceService;

  Future<Session> updateArchiveStatus({
    required String sessionId,
    required bool archived,
    required bool deleteWorktree,
    required bool deleteBranch,
    required bool force,
  }) async {
    final sessionDto = await _getSessionDto(sessionId: sessionId);
    return archived
        ? _doArchive(
            sessionDto: sessionDto,
            deleteWorktree: deleteWorktree,
            deleteBranch: deleteBranch,
            force: force,
          )
        : _doUnarchive(sessionDto: sessionDto);
  }

  Future<SessionDto> _getSessionDto({required String sessionId}) async {
    if (await _sessionRepository.getStoredSession(sessionId: sessionId) case final sessionDto?) {
      return sessionDto;
    }
    final projectId = await _sessionRepository.findProjectIdForSession(sessionId: sessionId);
    if (projectId == null) {
      throw SessionNotFoundException();
    }
    await _sessionPersistenceService.createSession(
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
    required SessionDto sessionDto,
    required bool deleteWorktree,
    required bool deleteBranch,
    required bool force,
  }) async {
    final archivedAt = DateTime.now().millisecondsSinceEpoch;
    await _cleanupIfNeeded(
      sessionDto: sessionDto,
      deleteWorktree: deleteWorktree,
      deleteBranch: deleteBranch,
      force: force,
    );
    if (await _sessionRepository.getSessionForProject(
          projectId: sessionDto.projectId,
          sessionId: sessionDto.sessionId,
        ) ==
        null) {
      throw SessionNotFoundException();
    }
    await _sessionPersistenceService.archiveSession(
      sessionId: sessionDto.sessionId,
      archivedAt: archivedAt,
    );
    unawaited(
      _sessionRepository.notifySessionArchived(sessionId: sessionDto.sessionId).catchError((Object e) {
        Log.w("[archive] failed to notify plugin for session ${sessionDto.sessionId}: $e");
      }),
    );
    final session = await _sessionRepository.getSessionForProject(
      projectId: sessionDto.projectId,
      sessionId: sessionDto.sessionId,
    );
    if (session == null) {
      throw SessionNotFoundException();
    }
    return session;
  }

  Future<void> _cleanupIfNeeded({
    required SessionDto sessionDto,
    required bool deleteWorktree,
    required bool deleteBranch,
    required bool force,
  }) async {
    if (!(deleteWorktree || deleteBranch)) {
      return;
    }
    if (sessionDto case SessionDto(
      :final projectId,
      worktreePath: final worktreePath?,
      branchName: final branchName?,
    )) {
      final cleanupResult = await performWorktreeCleanup(
        worktreeService: _worktreeService,
        sessionRepository: _sessionRepository,
        sessionId: sessionDto.sessionId,
        projectId: projectId,
        worktreePath: worktreePath,
        branchName: branchName,
        deleteWorktree: deleteWorktree,
        deleteBranch: deleteBranch,
        force: force,
      );
      if (cleanupResult case CleanupRejected(:final rejection)) {
        throw SessionArchiveConflictException(rejection: rejection);
      }
    }
  }

  Future<Session> _doUnarchive({required SessionDto sessionDto}) async {
    await _sessionPersistenceService.unarchiveSession(sessionId: sessionDto.sessionId);
    if (sessionDto case SessionDto(
      isDedicated: true,
      :final projectId,
      worktreePath: final worktreePath?,
      branchName: final branchName?,
    )) {
      final hasWorktreeOnDisk = Directory(worktreePath).existsSync();
      if (!hasWorktreeOnDisk) {
        final restoreBaseBranch = await _resolveRestoreBaseBranch(
          projectId: projectId,
          storedBaseBranch: sessionDto.baseBranch,
        );
        await _worktreeService.restoreWorktree(
          projectPath: projectId,
          worktreePath: worktreePath,
          branchName: branchName,
          baseBranch: restoreBaseBranch,
          baseCommit: _normalizeBaseCommit(baseCommit: sessionDto.baseCommit),
        );
      }
    }
    final session = await _sessionRepository.getSessionForProject(
      projectId: sessionDto.projectId,
      sessionId: sessionDto.sessionId,
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
    final resolved = await _worktreeService.resolveBaseBranchAndCommit(projectPath: projectId);
    if (resolved == null) {
      throw SessionInitializationException();
    }
    return resolved.baseBranch;
  }

  String? _normalizeBaseCommit({required String? baseCommit}) {
    if (baseCommit == null) {
      return null;
    }
    final trimmed = baseCommit.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    return trimmed;
  }
}
