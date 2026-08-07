import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log;

import "../repositories/session_repository.dart";
import "chat_history_service.dart";
import "session_cleanup_result.dart";
import "session_lifecycle_service.dart";
import "session_mutation_dispatcher.dart";

/// Owns the complete cleanup-and-delete workflow for one session family.
class SessionDeletionService {
  final SessionLifecycleService _sessionLifecycleService;
  final SessionMutationDispatcher _sessionMutationDispatcher;
  final SessionRepository _sessionRepository;
  final ChatHistoryService _chatHistoryService;

  SessionDeletionService({
    required SessionLifecycleService sessionLifecycleService,
    required SessionMutationDispatcher sessionMutationDispatcher,
    required SessionRepository sessionRepository,
    required ChatHistoryService chatHistoryService,
  }) : _sessionLifecycleService = sessionLifecycleService,
       _sessionMutationDispatcher = sessionMutationDispatcher,
       _sessionRepository = sessionRepository,
       _chatHistoryService = chatHistoryService;

  Future<CleanupResult> deleteSession({
    required String sessionId,
    required bool deleteWorktree,
    required bool deleteBranch,
    required bool force,
  }) async {
    // Read the subtree before the delete, which removes the rows that define
    // it. The two stores are coordinated here rather than inside
    // SessionRepository, which owns no history dependency.
    final subtreeIds = await _sessionRepository.getSessionSubtreeIds(sessionId: sessionId);
    final result = await _sessionMutationDispatcher.deleteSession(
      sessionId: sessionId,
      cleanup: () => _sessionLifecycleService.cleanupAlreadyReserved(
        sessionId: sessionId,
        deleteWorktree: deleteWorktree,
        deleteBranch: deleteBranch,
        force: force,
      ),
    );
    if (result is CleanupSuccess) {
      await _purgeHistory(sessionIds: subtreeIds);
    }
    return result;
  }

  /// Best-effort: the session rows are already gone, so a failure here leaves
  /// orphan history that the startup reconcile removes.
  Future<void> _purgeHistory({required List<String> sessionIds}) async {
    for (final sessionId in sessionIds) {
      try {
        await _chatHistoryService.purgeSessionHistory(sessionId: sessionId);
      } on Object catch (error, stackTrace) {
        Log.w(
          "Failed to purge chat history for deleted session $sessionId; "
          "retrying on next startup reconcile",
          error,
          stackTrace,
        );
      }
    }
  }
}
