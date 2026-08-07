import "../../api/attachment_spill_storage.dart";
import "../../api/database/history/chat_history_dao.dart";

/// Owns the stored representation of chat history: database rows and the
/// attachment spill files their part payloads reference.
class ChatHistoryRepository {
  ChatHistoryRepository({
    required ChatHistoryDao chatHistoryDao,
    required AttachmentSpillStorage attachmentSpillStorage,
  }) : _chatHistoryDao = chatHistoryDao,
       _attachmentSpillStorage = attachmentSpillStorage;

  final ChatHistoryDao _chatHistoryDao;
  final AttachmentSpillStorage _attachmentSpillStorage;

  /// Drops every trace of [sessionIds] from the store.
  ///
  /// Rows go first so a failure between the two steps leaves orphan bytes
  /// (harmless, removed by the next purge) rather than rows referencing spill
  /// files that no longer exist. Deleting a session family is one transaction
  /// and one vacuum pass, not one of each per descendant.
  Future<void> purgeSessions({required List<String> sessionIds}) async {
    if (sessionIds.isEmpty) return;
    await _chatHistoryDao.deleteSessionRows(sessionIds: sessionIds);
    // Every session is attempted even if one directory refuses to go, so a
    // single failure cannot strand the rest of the family's bytes on disk.
    // The first failure is reported once the rest of the work is done.
    Object? firstError;
    StackTrace? firstStackTrace;
    for (final sessionId in sessionIds) {
      try {
        await _attachmentSpillStorage.deleteSession(sessionId: sessionId);
      } on Object catch (error, stackTrace) {
        firstError ??= error;
        firstStackTrace ??= stackTrace;
      }
    }
    await _chatHistoryDao.reclaimFreedPages();
    if (firstError != null) Error.throwWithStackTrace(firstError, firstStackTrace!);
  }
}
