import "dart:io";

import "package:sesori_shared/sesori_shared.dart";

import "../foundation/process_runner.dart";
import "../persistence/daos/session_dao.dart";
import "../session_diffs/compute_session_diffs.dart";
import "../session_diffs/exceptions.dart";
import "request_handler.dart";

/// Returns file diffs for a session's worktree via bridge-side `git diff`.
class GetSessionDiffsHandler extends BodyRequestHandler<SessionIdRequest, SessionDiffsResponse> {
  final SessionDao _sessionDao;
  final ProcessRunner _processRunner;

  GetSessionDiffsHandler(this._sessionDao, {required ProcessRunner processRunner})
    : _processRunner = processRunner,
      super(
        HttpMethod.post,
        "/session/diffs",
        fromJson: SessionIdRequest.fromJson,
      );

  @override
  Future<SessionDiffsResponse> handle(
    RelayRequest request, {
    required SessionIdRequest body,
    required Map<String, String> pathParams,
    required Map<String, String> queryParams,
    required String? fragment,
  }) async {
    final sessionId = body.sessionId;

    final session = await _sessionDao.getSession(sessionId: sessionId);
    if (session == null) {
      throw buildErrorResponse(request, 404, "session not found: $sessionId");
    }

    final worktreePath = session.worktreePath;
    final baseCommit = session.baseCommit;
    if (worktreePath == null || baseCommit == null) return const SessionDiffsResponse(diffs: []);
    if (!Directory(worktreePath).existsSync()) return const SessionDiffsResponse(diffs: []);

    final List<FileDiff> diffs;
    try {
      diffs = await computeSessionDiffs(
        worktreePath: worktreePath,
        baseBranch: baseCommit,
        processRunner: _processRunner,
      );
    } on BaseBranchUnreachableException catch (error) {
      throw buildErrorResponse(request, 422, error.message);
    } on GitDiffQueryException catch (error) {
      throw buildErrorResponse(request, 500, error.message);
    }

    return SessionDiffsResponse(diffs: diffs);
  }
}
