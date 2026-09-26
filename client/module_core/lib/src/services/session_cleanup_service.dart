import "package:injectable/injectable.dart";
import "package:sesori_auth/sesori_auth.dart";

import "../repositories/models/session_cleanup_rejection.dart";
import "../repositories/session_repository.dart";
import "models/session_cleanup_outcome.dart";

/// Archives and deletes sessions, and owns the one rule for a worktree cleanup
/// the bridge refuses.
///
/// A refusal over something the user owns is rethrown as
/// [SessionCleanupRejectedException] for them to decide on.
@lazySingleton
class SessionCleanupService({required final SessionRepository _repository}) {
  Future<ApiResponse<SessionCleanupOutcome>> archiveSession({
    required String sessionId,
    required bool deleteWorktree,
    required bool force,
  }) => _cleanUp(
    deleteWorktree: deleteWorktree,
    request: ({required deleteWorktree}) =>
        _repository.archiveSession(sessionId: sessionId, deleteWorktree: deleteWorktree, force: force),
  );

  Future<ApiResponse<SessionCleanupOutcome>> deleteSession({
    required String sessionId,
    required bool deleteWorktree,
    required bool force,
  }) => _cleanUp(
    deleteWorktree: deleteWorktree,
    request: ({required deleteWorktree}) =>
        _repository.deleteSession(sessionId: sessionId, deleteWorktree: deleteWorktree, force: force),
  );

  Future<ApiResponse<SessionCleanupOutcome>> _cleanUp<T>({
    required bool deleteWorktree,
    required Future<ApiResponse<T>> Function({required bool deleteWorktree}) request,
  }) async {
    try {
      return _outcome(
        response: await request(deleteWorktree: deleteWorktree),
        outcome: SessionCleanupOutcome.completed,
      );
    } on SessionCleanupRejectedException catch (error) {
      // A worktree another live session still uses is not the user's problem to
      // solve: go ahead and leave that worktree to the other one. The retry
      // sends deleteWorktree: false, so it cannot be refused again, and a
      // refusal that names no issue is never retried.
      if (!deleteWorktree || !error.rejection.isOnlySharedWorktree) rethrow;
      return _outcome(
        response: await request(deleteWorktree: false),
        outcome: SessionCleanupOutcome.sharedWorktreeKept,
      );
    }
  }

  ApiResponse<SessionCleanupOutcome> _outcome<T>({
    required ApiResponse<T> response,
    required SessionCleanupOutcome outcome,
  }) => switch (response) {
    SuccessResponse() => ApiResponse.success(outcome),
    ErrorResponse(:final error) => ApiResponse.error(error),
  };
}
