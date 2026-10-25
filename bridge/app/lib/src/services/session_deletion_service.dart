import "dart:async";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log;

import "../repositories/scratch_repository.dart";
import "../repositories/session_repository.dart";
import "chat_history_service.dart";
import "session_cleanup_result.dart";
import "session_lifecycle_service.dart";
import "session_mutation_dispatcher.dart";

/// Owns the complete cleanup-and-delete workflow for one session family.
class SessionDeletionService({
  required final SessionLifecycleService _sessionLifecycleService,
  required final SessionMutationDispatcher _sessionMutationDispatcher,
  required final ChatHistoryService _chatHistoryService,
  required final ScratchRepository _scratchRepository,
}) {
  Future<CleanupResult> deleteSession({
    required String sessionId,
    required bool deleteWorktree,
    required bool force,
    required bool deleteSessionFolder,
  }) {
    // The two stores are coordinated here rather than inside
    // SessionRepository, which owns no history dependency.
    return _sessionMutationDispatcher.deleteSession(
      sessionId: sessionId,
      cleanup: () => _sessionLifecycleService.cleanupAlreadyReserved(
        sessionId: sessionId,
        deleteWorktree: deleteWorktree,
        force: force,
      ),
      onDeleted: (deleted) async {
        await _purgeHistory(deleted.sessionIds);
        if (deleteSessionFolder) {
          // Not awaited: the family lock must not be held while a large
          // folder is removed.
          unawaited(_deleteSessionFolder(deleted: deleted));
        }
      },
    );
  }

  /// Best-effort: the session rows are already gone, so a failure here leaves
  /// orphan history that the startup reconcile removes.
  Future<void> _purgeHistory(List<String> sessionIds) async {
    try {
      // Deletion removes the archive too: the session is gone, so an audit
      // file for it would outlive the thing it audits.
      await _chatHistoryService.purgeSessionsHistory(sessionIds: sessionIds, includeArchive: true);
    } on Object catch (error, stackTrace) {
      Log.w(
        "Failed to purge chat history for ${sessionIds.length} deleted "
        "session(s); retrying on next startup reconcile",
        error,
        stackTrace,
      );
    }
  }

  /// Best-effort: the session is already gone, so a failure leaves only its
  /// folder on disk.
  Future<void> _deleteSessionFolder({required DeletedSessionSubtree deleted}) async {
    final directory = deleted.session.directory;
    try {
      await _scratchRepository.deleteSessionDirectoryIfUnused(path: directory);
    } on Object catch (error, stackTrace) {
      Log.w("Failed to delete the folder $directory of deleted session ${deleted.session.id}", error, stackTrace);
    }
  }
}
