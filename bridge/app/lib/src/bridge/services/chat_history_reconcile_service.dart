import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log;

import "../repositories/session_repository.dart";
import "chat_history_service.dart";

/// Startup owner of consistency between `sesori.db` and the history store.
///
/// It reads session identity from the main database but mutates only through
/// [ChatHistoryService], which stays the single writer of the store.
class ChatHistoryReconcileService({
    required SessionRepository sessionRepository,
    required ChatHistoryService chatHistoryService,
  }) {
  this : _sessionRepository = sessionRepository,
       _chatHistoryService = chatHistoryService;

  final SessionRepository _sessionRepository;
  final ChatHistoryService _chatHistoryService;

  Future<void> reconcile() async {
    try {
      await _reconcile();
    } on Object catch (error, stackTrace) {
      Log.w("Chat history reconciliation failed; continuing startup", error, stackTrace);
    }
  }

  /// Purges history for sessions the catalog no longer knows about — deleted
  /// while the bridge was down, or whose inline purge failed. An archived
  /// session keeps its catalog row, so row existence is the whole mapping.
  ///
  /// This can never fire for a session that merely disappeared from its
  /// backend: catalog import is non-destructive, so such a session keeps its
  /// row and therefore its history. The comparison reads only the local
  /// databases — no plugin request is involved, so a failing backend cannot
  /// be mistaken for deleted sessions.
  Future<void> _reconcile() async {
    final storedSessionIds = await _chatHistoryService.getStoredSessionIds();
    final archivedSessionIds = await _chatHistoryService.getArchivedSessionIds();
    final trackedSessionIds = {...storedSessionIds, ...archivedSessionIds};
    if (trackedSessionIds.isEmpty) return;

    final knownSessionIds = await _sessionRepository.getExistingSessionIds(sessionIds: trackedSessionIds);
    final orphanIds = trackedSessionIds.difference(knownSessionIds).toList(growable: false)..sort();
    for (final sessionId in orphanIds) {
      try {
        await _chatHistoryService.purgeSessionHistory(sessionId: sessionId, includeArchive: true);
      } on Object catch (error, stackTrace) {
        Log.w(
          "Failed to purge orphan chat history for session $sessionId; "
          "retrying next startup",
          error,
          stackTrace,
        );
      }
    }

    // A crash between the archive flip and the purge leaves both a durable
    // audit file and the live rows it replaced. The file is authoritative
    // then, so finish the interrupted purge.
    //
    // Only for sessions the catalog reports as archived: export writes the
    // audit file *before* the flip, so a session with a file but no
    // `archivedAt` had its archive fail before completing. Its live rows are
    // still the only copy and must be kept — the orphan file is harmless and
    // the next archive attempt overwrites it.
    final withAudit = storedSessionIds.intersection(archivedSessionIds).difference(orphanIds.toSet());
    final duplicated = await _sessionRepository.getArchivedSessionIds(sessionIds: withAudit);
    for (final sessionId in duplicated.toList(growable: false)..sort()) {
      try {
        await _chatHistoryService.purgeSessionHistory(sessionId: sessionId);
      } on Object catch (error, stackTrace) {
        Log.w(
          "Failed to re-purge archived session $sessionId whose live history "
          "survived a crash; retrying next startup",
          error,
          stackTrace,
        );
      }
    }
  }
}
