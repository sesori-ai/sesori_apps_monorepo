import "dart:convert";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../persistence/daos/session_dao.dart";
import "../persistence/tables/session_table.dart";
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
    final wantsGitCleanup = deleteRequest.deleteWorktree || deleteRequest.deleteBranch;
    ({String projectId, String worktreePath, String branchName})? cleanupTarget;

    if (wantsGitCleanup) {
      if (sessionDto case SessionDto(
        :final projectId,
        worktreePath: final worktreePath?,
        branchName: final branchName?,
      )) {
        cleanupTarget = (
          projectId: projectId,
          worktreePath: worktreePath,
          branchName: branchName,
        );
        if (deleteRequest.deleteWorktree && !deleteRequest.force) {
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
      }
    }

    try {
      await _plugin.deleteSession(sessionId);
    } on PluginApiException catch (error) {
      if (error.statusCode != 404) {
        rethrow;
      }
    }

    if (cleanupTarget case (
      projectId: final projectId,
      worktreePath: final worktreePath,
      branchName: final branchName,
    )) {
      if (deleteRequest.deleteWorktree) {
        final removed = await _worktreeService.removeWorktree(
          projectPath: projectId,
          worktreePath: worktreePath,
          force: deleteRequest.force,
        );
        if (!removed) {
          Log.w(
            "DeleteSessionHandler: failed to remove worktree for session $sessionId at $worktreePath",
          );
        }
      }
      if (deleteRequest.deleteBranch) {
        final deleted = await _worktreeService.deleteBranch(
          projectPath: projectId,
          branchName: branchName,
          force: deleteRequest.deleteWorktree ? true : deleteRequest.force,
        );
        if (!deleted) {
          Log.w(
            "DeleteSessionHandler: failed to delete branch $branchName for session $sessionId",
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
