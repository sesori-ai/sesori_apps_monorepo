import "dart:async";
import "dart:convert";
import "dart:io";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../persistence/daos/session_dao.dart";
import "../persistence/tables/session_table.dart";
import "../repositories/mappers/plugin_session_mapper.dart";
import "../worktree_service.dart";
import "request_handler.dart";
import "worktree_cleanup.dart";

/// Handles `PATCH /session/update/archive` — updates archive status for a session.
class UpdateSessionArchiveStatusHandler extends BodyRequestHandler<UpdateSessionArchiveRequest, Session> {
  final BridgePlugin _plugin;
  final WorktreeService _worktreeService;
  final SessionDao _sessionDao;

  UpdateSessionArchiveStatusHandler({
    required BridgePlugin plugin,
    required WorktreeService worktreeService,
    required SessionDao sessionDao,
  }) : _plugin = plugin,
       _worktreeService = worktreeService,
       _sessionDao = sessionDao,
       super(
         HttpMethod.patch,
         "/session/update/archive",
         fromJson: UpdateSessionArchiveRequest.fromJson,
       );

  @override
  Future<Session> handle(
    RelayRequest request, {
    required UpdateSessionArchiveRequest body,
    required Map<String, String> pathParams,
    required Map<String, String> queryParams,
    required String? fragment,
  }) async {
    final sessionId = body.sessionId;
    if (sessionId.isEmpty) {
      throw buildErrorResponse(request, 400, "empty session id");
    }

    final sessionDto = await _getSessionDto(
      request: request,
      sessionId: sessionId,
    );

    return body.archived
        ? _doArchive(
            request: request,
            sessionDto: sessionDto,
            body: body,
          )
        : _doUnarchive(
            request: request,
            sessionDto: sessionDto,
          );
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

  Future<({String projectId})?> _findPluginSessionAcrossProjects({
    required String sessionId,
  }) async {
    final projects = await _plugin.getProjects();
    for (final project in projects) {
      final pluginSession = await _fetchPluginSession(
        projectId: project.id,
        sessionId: sessionId,
      );
      if (pluginSession != null) {
        return (projectId: project.id);
      }
    }
    return null;
  }

  Session _withArchivedTime({required Session session, required int? archivedAt}) {
    final time = session.time;
    if (time == null) {
      return session;
    }
    return session.copyWith(
      time: time.copyWith(archived: archivedAt),
    );
  }

  Future<SessionDto> _getSessionDto({
    required RelayRequest request,
    required String sessionId,
  }) async {
    if (await _sessionDao.getSession(sessionId: sessionId) case final sessionDto?) {
      return sessionDto;
    }
    final pluginSessionLookup = await _findPluginSessionAcrossProjects(
      sessionId: sessionId,
    );
    if (pluginSessionLookup == null) {
      throw buildErrorResponse(request, 404, "session not found");
    }

    await _sessionDao.insertSession(
      sessionId: sessionId,
      projectId: pluginSessionLookup.projectId,
      isDedicated: true,
      createdAt: DateTime.now().millisecondsSinceEpoch,
      worktreePath: null,
      branchName: null,
      baseBranch: null,
      baseCommit: null,
    );

    if (await _sessionDao.getSession(sessionId: sessionId) case final sessionDto?) {
      return sessionDto;
    }
    throw buildErrorResponse(request, 500, "failed to initialize session");
  }

  Future<Session> _doArchive({
    required RelayRequest request,
    required SessionDto sessionDto,
    required UpdateSessionArchiveRequest body,
  }) async {
    final archivedAt = DateTime.now().millisecondsSinceEpoch;
    final shouldCleanupGit = body.deleteWorktree || body.deleteBranch;
    if (shouldCleanupGit) {
      if (sessionDto case SessionDto(
        :final projectId,
        worktreePath: final worktreePath?,
        branchName: final branchName?,
      )) {
        final cleanupResult = await performWorktreeCleanup(
          worktreeService: _worktreeService,
          sessionId: sessionDto.sessionId,
          projectId: projectId,
          worktreePath: worktreePath,
          branchName: branchName,
          deleteWorktree: body.deleteWorktree,
          deleteBranch: body.deleteBranch,
          force: body.force,
        );
        if (cleanupResult case CleanupRejected(:final rejection)) {
          // IMPORTANT: Do not change this response structure — the mobile app
          // parses the 409 body as SessionCleanupRejection JSON.
          throw RelayResponse(
            id: request.id,
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
      throw buildErrorResponse(request, 404, "session not found");
    }

    await _sessionDao.setArchived(sessionId: sessionDto.sessionId, archivedAt: archivedAt);

    // Fire-and-forget: notify the backend so it can reflect the archive state.
    // The local DB is authoritative — we don't block on or fail for this.
    unawaited(
      _plugin.archiveSession(sessionId: sessionDto.sessionId).catchError((Object e) {
        Log.w("[archive] failed to notify plugin for session ${sessionDto.sessionId}: $e");
      }),
    );

    final responseSession = _withArchivedTime(
      session: pluginSession.toSharedSession(),
      archivedAt: archivedAt,
    );
    return responseSession;
  }

  Future<Session> _doUnarchive({
    required RelayRequest request,
    required SessionDto sessionDto,
  }) async {
    await _sessionDao.clearArchived(sessionId: sessionDto.sessionId);

    if (sessionDto case SessionDto(
      isDedicated: true,
      :final projectId,
      worktreePath: final worktreePath?,
      branchName: final branchName?,
    )) {
      final hasWorktreeOnDisk = Directory(worktreePath).existsSync();
      if (!hasWorktreeOnDisk) {
        await _worktreeService.restoreWorktree(
          projectPath: projectId,
          worktreePath: worktreePath,
          branchName: branchName,
          baseBranch: sessionDto.baseBranch ?? "main",
          baseCommit: sessionDto.baseCommit,
        );
      }
    }

    final pluginSession = await _fetchPluginSession(
      projectId: sessionDto.projectId,
      sessionId: sessionDto.sessionId,
    );
    if (pluginSession == null) {
      throw buildErrorResponse(request, 404, "session not found");
    }

    final responseSession = _withArchivedTime(
      session: pluginSession.toSharedSession(),
      archivedAt: null,
    );
    return responseSession;
  }
}
