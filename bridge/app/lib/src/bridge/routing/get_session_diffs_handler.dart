import "dart:io";

import "package:sesori_shared/sesori_shared.dart";

import "../persistence/daos/session_dao.dart";
import "../worktree_service.dart" show ProcessRunner;
import "request_handler.dart";
import "session_diff_git_queries.dart";

/// Returns file diffs for a session's worktree via bridge-side `git diff`.
class GetSessionDiffsHandler extends GetRequestHandler<List<Map<String, dynamic>>> {
  final SessionDao _sessionDao;
  final ProcessRunner _processRunner;

  GetSessionDiffsHandler(this._sessionDao, {ProcessRunner? processRunner})
    : _processRunner = processRunner ?? Process.run,
      super("/session/:id/diff");

  @override
  Future<List<Map<String, dynamic>>> handle(
    RelayRequest request, {
    required Map<String, String> pathParams,
    required Map<String, String> queryParams,
    required String? fragment,
  }) async {
    final sessionId = pathParams["id"];
    if (sessionId == null || sessionId.isEmpty) {
      throw buildErrorResponse(request, 400, "missing session id");
    }

    final session = await _sessionDao.getSession(sessionId: sessionId);
    if (session == null) {
      throw buildErrorResponse(request, 404, "session not found: $sessionId");
    }

    final worktreePath = session.worktreePath;
    final baseCommit = session.baseCommit;
    if (worktreePath == null || baseCommit == null) return const [];
    if (!Directory(worktreePath).existsSync()) return const [];

    final List<FileDiff> diffs;
    try {
      diffs = await computeSessionDiffs(
        worktreePath: worktreePath,
        baseCommit: baseCommit,
        processRunner: _processRunner,
      );
    } on BaseCommitUnreachableException catch (error) {
      throw buildErrorResponse(request, 422, error.message);
    } on GitDiffQueryException catch (error) {
      throw buildErrorResponse(request, 500, error.message);
    }

    return diffs.map((diff) => diff.toJson()).toList();
  }
}
