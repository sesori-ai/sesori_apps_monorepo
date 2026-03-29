import "dart:convert";
import "dart:io";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../persistence/daos/session_dao.dart";
import "../persistence/tables/session_table.dart";
import "../worktree_service.dart";
import "plugin_session_mapper.dart";
import "request_handler.dart";

const _idParam = "id";

/// Handles `PATCH /session/:id` — updates archive status for a session.
class UpdateSessionArchiveStatusHandler extends RequestHandler {
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
       super(HttpMethod.patch, "/session/:$_idParam");

  @override
  Future<RelayResponse> handle(
    RelayRequest request, {
    required Map<String, String> pathParams,
    required Map<String, String> queryParams,
    String? fragment,
  }) async {
    final sessionId = pathParams[_idParam];
    if (sessionId == null || sessionId.isEmpty) {
      return buildErrorResponse(request, 400, "missing session id");
    }

    final UpdateSessionArchiveRequest archiveRequest;
    try {
      final decoded = jsonDecode(request.body ?? "{}");
      archiveRequest = UpdateSessionArchiveRequest.fromJson(
        switch (decoded) {
          final Map<String, dynamic> map => map,
          _ => throw const FormatException("invalid JSON body"),
        },
      );
    } on FormatException {
      return buildErrorResponse(request, 400, "invalid JSON body");
    } on Object {
      return buildErrorResponse(request, 400, "invalid JSON body");
    }

    var sessionDto = await _sessionDao.getSession(sessionId: sessionId);
    if (sessionDto == null) {
      final pluginSessionLookup = await _findPluginSessionAcrossProjects(
        sessionId: sessionId,
      );
      if (pluginSessionLookup == null) {
        return buildErrorResponse(request, 404, "session not found");
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
      sessionDto = await _sessionDao.getSession(sessionId: sessionId);
      if (sessionDto == null) {
        return buildErrorResponse(request, 500, "failed to initialize session");
      }
    }

    if (archiveRequest.archived) {
      final archivedAt = DateTime.now().millisecondsSinceEpoch;
      final cleanupResult = await _cleanupWorktreeIfRequested(
        request: request,
        sessionId: sessionId,
        sessionDto: sessionDto,
        deleteWorktree: archiveRequest.deleteWorktree,
        deleteBranch: archiveRequest.deleteBranch,
        force: archiveRequest.force,
      );
      if (cleanupResult case final RelayResponse rejection) {
        return rejection;
      }

      final pluginSession = await _fetchPluginSession(
        projectId: sessionDto.projectId,
        sessionId: sessionId,
      );
      if (pluginSession == null) {
        return buildErrorResponse(request, 404, "session not found");
      }

      await _sessionDao.setArchived(sessionId: sessionId, archivedAt: archivedAt);

      final responseSession = _withArchivedTime(
        session: pluginSession.toSharedSession(),
        archivedAt: archivedAt,
      );
      return buildOkJsonResponse(request, jsonEncode(responseSession.toJson()));
    }

    await _sessionDao.clearArchived(sessionId: sessionId);

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
      sessionId: sessionId,
    );
    if (pluginSession == null) {
      return buildErrorResponse(request, 404, "session not found");
    }

    final responseSession = _withArchivedTime(
      session: pluginSession.toSharedSession(),
      archivedAt: null,
    );
    return buildOkJsonResponse(request, jsonEncode(responseSession.toJson()));
  }

  Future<RelayResponse?> _cleanupWorktreeIfRequested({
    required RelayRequest request,
    required String sessionId,
    required SessionDto sessionDto,
    required bool deleteWorktree,
    required bool deleteBranch,
    required bool force,
  }) async {
    final shouldCleanupGit = deleteWorktree || deleteBranch;
    if (!shouldCleanupGit) {
      return null;
    }

    final worktreePath = sessionDto.worktreePath;
    final branchName = sessionDto.branchName;
    if (worktreePath == null || branchName == null) {
      return null;
    }

    if (deleteWorktree && !force) {
      final safety = await _worktreeService.checkWorktreeSafety(
        worktreePath: worktreePath,
        expectedBranch: branchName,
      );
      if (safety case WorktreeUnsafe(:final issues)) {
        final rejection = SessionCleanupRejection(
          issues: _mapCleanupIssues(issues: issues),
        );
        return RelayResponse(
          id: request.id,
          status: 409,
          headers: {"content-type": "application/json"},
          body: jsonEncode(rejection.toJson()),
        );
      }
    }

    if (deleteWorktree) {
      final removed = await _worktreeService.removeWorktree(
        projectPath: sessionDto.projectId,
        worktreePath: worktreePath,
        force: force,
      );
      if (!removed) {
        Log.w(
          "UpdateSessionArchiveStatusHandler: removeWorktree failed for session=$sessionId worktreePath=$worktreePath",
        );
      }
    }
    if (deleteBranch) {
      final branchDeleted = await _worktreeService.deleteBranch(
        projectPath: sessionDto.projectId,
        branchName: branchName,
        force: deleteWorktree ? true : force,
      );
      if (!branchDeleted) {
        Log.w(
          "UpdateSessionArchiveStatusHandler: deleteBranch failed for session=$sessionId branch=$branchName",
        );
      }
    }

    return null;
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

  List<CleanupIssue> _mapCleanupIssues({required List<SafetyIssue> issues}) {
    return issues
        .map(
          (issue) => switch (issue) {
            UnstagedChanges() => const CleanupIssue.unstagedChanges(),
            BranchMismatch(:final expected, :final actual) => CleanupIssue.branchMismatch(
              expected: expected,
              actual: actual,
            ),
            WorktreeNotFound() => const CleanupIssue.worktreeNotFound(),
          },
        )
        .toList();
  }
}
