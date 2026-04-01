import "dart:convert";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../persistence/daos/session_dao.dart";
import "../persistence/tables/session_table.dart";
import "../worktree_service.dart";
import "request_handler.dart";
import "worktree_cleanup.dart";

/// Handles `DELETE /session/delete` — deletes a session.
class DeleteSessionHandler extends BodyRequestHandler<DeleteSessionRequest, SuccessEmptyResponse> {
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
       super(
         HttpMethod.delete,
         "/session/delete",
         fromJson: DeleteSessionRequest.fromJson,
       );

  @override
  Future<SuccessEmptyResponse> handle(
    RelayRequest request, {
    required DeleteSessionRequest body,
    required Map<String, String> pathParams,
    required Map<String, String> queryParams,
    required String? fragment,
  }) async {
    final sessionId = body.sessionId;
    if (sessionId.isEmpty) {
      throw buildErrorResponse(request, 400, "empty session id");
    }

    final sessionDto = await _sessionDao.getSession(sessionId: sessionId);
    final wantsGitCleanup = body.deleteWorktree || body.deleteBranch;
    if (wantsGitCleanup) {
      if (sessionDto case SessionDto(
        :final projectId,
        worktreePath: final worktreePath?,
        branchName: final branchName?,
      )) {
        final cleanupResult = await performWorktreeCleanup(
          worktreeService: _worktreeService,
          sessionId: sessionId,
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

    try {
      await _plugin.deleteSession(sessionId);
    } on PluginApiException catch (error) {
      if (error.statusCode != 404) {
        rethrow;
      }
    }

    if (sessionDto != null) {
      await _sessionDao.deleteSession(sessionId: sessionId);
    }

    return const SuccessEmptyResponse();
  }
}
