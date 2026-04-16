import "dart:async";
import "dart:convert";
import "dart:io";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../persistence/tables/session_table.dart";
import "../repositories/mappers/plugin_session_mapper.dart";
import "../repositories/session_repository.dart";
import "../services/session_persistence_service.dart";
import "../services/worktree_cleanup_service.dart";
import "../services/worktree_service.dart";

class SessionArchiveStatusService {
  final BridgePlugin _plugin;
  final WorktreeService _worktreeService;
  final SessionRepository _sessionRepository;
  final SessionPersistenceService _sessionPersistenceService;

  SessionArchiveStatusService({
    required BridgePlugin plugin,
    required WorktreeService worktreeService,
    required SessionRepository sessionRepository,
    required SessionPersistenceService sessionPersistenceService,
  }) : _plugin = plugin,
       _worktreeService = worktreeService,
       _sessionRepository = sessionRepository,
       _sessionPersistenceService = sessionPersistenceService;

  Future<Session> updateArchiveStatus({
    required String requestId,
    required String sessionId,
    required bool archived,
    required bool deleteWorktree,
    required bool deleteBranch,
    required bool force,
  }) async {
    final sessionDto = await _getSessionDto(requestId: requestId, sessionId: sessionId);
    return archived
        ? _archiveSession(
            requestId: requestId,
            sessionDto: sessionDto,
            deleteWorktree: deleteWorktree,
            deleteBranch: deleteBranch,
            force: force,
          )
        : _unarchiveSession(requestId: requestId, sessionDto: sessionDto);
  }

  Future<PluginSession?> _fetchPluginSession({
    required String projectId,
    required String sessionId,
  }) async {
    final sessions = await _plugin.getSessions(projectId);
    for (final session in sessions) {
      if (session.id == sessionId) {
        return session;
      }
    }
    return null;
  }

  Future<({String projectId})?> _findPluginSessionAcrossProjects({required String sessionId}) async {
    final projects = await _plugin.getProjects();
    for (final project in projects) {
      final pluginSession = await _fetchPluginSession(projectId: project.id, sessionId: sessionId);
      if (pluginSession != null) {
        return (projectId: project.id);
      }
    }
    return null;
  }

  /// Builds the response Session by merging plugin data with DB state.
  ///
  /// Mirrors the merge that [SessionRepository.getSessionsForProject] performs
  /// for the listing endpoint, so archive/unarchive responses stay consistent
  /// with what subsequent list refreshes will return.
  Session _buildResponseSession({
    required PluginSession pluginSession,
    required SessionDto sessionDto,
    required int? archivedAt,
  }) {
    final base = pluginSession.toSharedSession(
      hasWorktree: sessionDto.isDedicated && sessionDto.worktreePath != null,
    );
    final time = base.time;
    final mergedTime = time != null
        ? time.copyWith(archived: archivedAt)
        : SessionTime(created: 0, updated: 0, archived: archivedAt);
    return base.copyWith(time: mergedTime);
  }

  Future<SessionDto> _getSessionDto({
    required String requestId,
    required String sessionId,
  }) async {
    if (await _sessionRepository.getStoredSession(sessionId: sessionId) case final sessionDto?) {
      return sessionDto;
    }
    final pluginSessionLookup = await _findPluginSessionAcrossProjects(sessionId: sessionId);
    if (pluginSessionLookup == null) {
      throw RelayResponse(id: requestId, status: 404, headers: const {}, body: "session not found");
    }

    await _sessionPersistenceService.createSession(
      sessionId: sessionId,
      projectId: pluginSessionLookup.projectId,
      isDedicated: false,
      createdAt: DateTime.now().millisecondsSinceEpoch,
      worktreePath: null,
      branchName: null,
      baseBranch: null,
      baseCommit: null,
    );

    if (await _sessionRepository.getStoredSession(sessionId: sessionId) case final sessionDto?) {
      return sessionDto;
    }
    throw RelayResponse(id: requestId, status: 500, headers: const {}, body: "failed to initialize session");
  }

  Future<Session> _archiveSession({
    required String requestId,
    required SessionDto sessionDto,
    required bool deleteWorktree,
    required bool deleteBranch,
    required bool force,
  }) async {
    final archivedAt = DateTime.now().millisecondsSinceEpoch;
    final shouldCleanupGit = deleteWorktree || deleteBranch;
    if (shouldCleanupGit) {
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
          // IMPORTANT: Do not change this response structure — the mobile app
          // parses the 409 body as SessionCleanupRejection JSON.
          throw RelayResponse(
            id: requestId,
            status: 409,
            headers: {"content-type": "application/json"},
            body: jsonEncode(rejection.toJson()),
          );
        }
      }
    }

    final pluginSession = await _fetchPluginSession(
      projectId: sessionDto.projectId,
      sessionId: sessionDto.sessionId,
    );
    if (pluginSession == null) {
      throw RelayResponse(id: requestId, status: 404, headers: const {}, body: "session not found");
    }

    await _sessionPersistenceService.archiveSession(
      sessionId: sessionDto.sessionId,
      archivedAt: archivedAt,
    );

    unawaited(
      _plugin.archiveSession(sessionId: sessionDto.sessionId).catchError((Object e) {
        Log.w("[archive] failed to notify plugin for session ${sessionDto.sessionId}: $e");
      }),
    );

    return _buildResponseSession(
      pluginSession: pluginSession,
      sessionDto: sessionDto,
      archivedAt: archivedAt,
    );
  }

  Future<Session> _unarchiveSession({
    required String requestId,
    required SessionDto sessionDto,
  }) async {
    await _sessionPersistenceService.unarchiveSession(sessionId: sessionDto.sessionId);

    if (sessionDto case SessionDto(
      isDedicated: true,
      :final projectId,
      worktreePath: final worktreePath?,
      branchName: final branchName?,
    )) {
      final hasWorktreeOnDisk = Directory(worktreePath).existsSync();
      if (!hasWorktreeOnDisk) {
        final restoreBaseBranch = switch (sessionDto.baseBranch?.trim()) {
          final value? when value.isNotEmpty => value,
          _ => "main",
        };
        final restoreBaseCommit = switch (sessionDto.baseCommit?.trim()) {
          final value? when value.isNotEmpty => value,
          _ => null,
        };
        final restored = await _worktreeService.restoreWorktree(
          projectPath: projectId,
          worktreePath: worktreePath,
          branchName: branchName,
          baseBranch: restoreBaseBranch,
          baseCommit: restoreBaseCommit,
        );
        if (!restored) {
          Log.w("[unarchive] failed to restore worktree for session ${sessionDto.sessionId}");
        }
      }
    }

    final pluginSession = await _fetchPluginSession(
      projectId: sessionDto.projectId,
      sessionId: sessionDto.sessionId,
    );
    if (pluginSession == null) {
      throw RelayResponse(id: requestId, status: 404, headers: const {}, body: "session not found");
    }

    return _buildResponseSession(
      pluginSession: pluginSession,
      sessionDto: sessionDto,
      archivedAt: null,
    );
  }
}
