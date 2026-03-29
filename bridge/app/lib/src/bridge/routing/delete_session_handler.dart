import "dart:convert";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../persistence/daos/session_dao.dart";
import "../worktree_service.dart";
import "request_handler.dart";

const _idParam = "id";

/// Handles `DELETE /session/:id` — deletes a session.
class DeleteSessionHandler extends RequestHandler {
  final BridgePlugin _plugin;
  final WorktreeService _worktreeService;
  final SessionDao _sessionDao;

  DeleteSessionHandler({
    required BridgePlugin plugin,
    required WorktreeService worktreeService,
    required SessionDao sessionDao,
  }) : _plugin = plugin,
       _worktreeService = worktreeService,
       _sessionDao = sessionDao,
       super(HttpMethod.delete, "/session/:$_idParam");

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

    final DeleteSessionRequest deleteRequest;
    try {
      final decoded = jsonDecode(request.body ?? "{}");
      deleteRequest = DeleteSessionRequest.fromJson(
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

    final sessionDto = await _sessionDao.getSession(sessionId: sessionId);
    final worktreePath = sessionDto?.worktreePath;
    final shouldCleanupGit =
        sessionDto != null && worktreePath != null && (deleteRequest.deleteWorktree || deleteRequest.deleteBranch);
    final cleanupSession = shouldCleanupGit ? sessionDto! : null;
    final cleanupWorktreePath = shouldCleanupGit ? worktreePath! : null;

    var isSharedWorktree = false;
    if (shouldCleanupGit && deleteRequest.deleteWorktree) {
      isSharedWorktree = (await _sessionDao.getSessionsByProject(projectId: cleanupSession!.projectId)).any(
        (session) => session.sessionId != sessionId && session.worktreePath == cleanupWorktreePath,
      );
    }

    if (shouldCleanupGit && deleteRequest.deleteWorktree && !isSharedWorktree && !deleteRequest.force) {
      final safety = await _worktreeService.checkWorktreeSafety(
        worktreePath: cleanupWorktreePath!,
        expectedBranch: cleanupSession!.branchName!,
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

    try {
      await _plugin.deleteSession(sessionId);
    } on PluginApiException catch (error) {
      if (error.statusCode != 404) {
        rethrow;
      }
    }

    if (shouldCleanupGit) {
      if (deleteRequest.deleteWorktree && !isSharedWorktree) {
        final removed = await _worktreeService.removeWorktree(
          projectPath: cleanupSession!.projectId,
          worktreePath: cleanupWorktreePath!,
          force: deleteRequest.force,
        );
        if (!removed) {
          Log.w(
            "DeleteSessionHandler: failed to remove worktree for session $sessionId at $worktreePath",
          );
        }
      }
      if (deleteRequest.deleteBranch && sessionDto.branchName != null) {
        final deleted = await _worktreeService.deleteBranch(
          projectPath: cleanupSession!.projectId,
          branchName: cleanupSession.branchName!,
          force: deleteRequest.deleteWorktree ? true : deleteRequest.force,
        );
        if (!deleted) {
          Log.w(
            "DeleteSessionHandler: failed to delete branch ${cleanupSession.branchName} for session $sessionId",
          );
        }
      }
    }

    if (sessionDto != null) {
      await _sessionDao.deleteSession(sessionId: sessionId);
    }

    return RelayResponse(
      id: request.id,
      status: 200,
      headers: {},
      body: null,
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
