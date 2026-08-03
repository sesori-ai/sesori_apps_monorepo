import "session_cleanup_result.dart";
import "session_lifecycle_service.dart";
import "session_mutation_dispatcher.dart";

/// Owns the complete cleanup-and-delete workflow for one session family.
class SessionDeletionService {
  final SessionLifecycleService _sessionLifecycleService;
  final SessionMutationDispatcher _sessionMutationDispatcher;

  SessionDeletionService({
    required SessionLifecycleService sessionLifecycleService,
    required SessionMutationDispatcher sessionMutationDispatcher,
  }) : _sessionLifecycleService = sessionLifecycleService,
       _sessionMutationDispatcher = sessionMutationDispatcher;

  Future<CleanupResult> deleteSession({
    required String sessionId,
    required bool deleteWorktree,
    required bool deleteBranch,
    required bool force,
  }) {
    return _sessionMutationDispatcher.deleteSession(
      sessionId: sessionId,
      cleanup: () => _sessionLifecycleService.cleanupAlreadyReserved(
        sessionId: sessionId,
        deleteWorktree: deleteWorktree,
        deleteBranch: deleteBranch,
        force: force,
      ),
    );
  }
}
