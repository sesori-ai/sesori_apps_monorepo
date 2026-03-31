import "dart:convert";
import "dart:io";

import "package:sesori_shared/sesori_shared.dart";

import "../persistence/daos/session_dao.dart";
import "../worktree_service.dart" show ProcessRunner;
import "request_handler.dart";
import "session_diff_git_queries.dart";

class GetSessionDiffsHandler extends RequestHandler {
  final SessionDao _sessionDao;
  final ProcessRunner _processRunner;

  GetSessionDiffsHandler(this._sessionDao, {ProcessRunner? processRunner})
    : _processRunner = processRunner ?? Process.run,
      super(HttpMethod.get, "/session/:id/diff");

  @override
  Future<RelayResponse> handle(
    RelayRequest request, {
    required Map<String, String> pathParams,
    required Map<String, String> queryParams,
    String? fragment,
  }) async {
    final sessionId = pathParams["id"];
    if (sessionId == null || sessionId.isEmpty) {
      return buildErrorResponse(request, 400, "missing session id");
    }

    final session = await _sessionDao.getSession(sessionId: sessionId);
    if (session == null) {
      return buildErrorResponse(request, 404, "session not found: $sessionId");
    }

    final worktreePath = session.worktreePath;
    final baseCommit = session.baseCommit;
    if (worktreePath == null || baseCommit == null) {
      return _emptyResponse(request);
    }

    if (!Directory(worktreePath).existsSync()) {
      return _emptyResponse(request);
    }

    final List<FileDiff> diffs;
    try {
      diffs = await computeSessionDiffs(
        worktreePath: worktreePath,
        baseCommit: baseCommit,
        processRunner: _processRunner,
      );
    } on BaseCommitUnreachableException catch (error) {
      return buildErrorResponse(request, 422, error.message);
    } on GitDiffQueryException catch (error) {
      return buildErrorResponse(request, 500, error.message);
    }

    final body = jsonEncode(diffs.map((diff) => diff.toJson()).toList());
    return buildOkJsonResponse(request, body);
  }

  RelayResponse _emptyResponse(RelayRequest request) {
    return buildOkJsonResponse(request, "[]");
  }
}
