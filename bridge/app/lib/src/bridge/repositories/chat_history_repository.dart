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

  /// Drops every trace of [sessionId] from the store.
  ///
  /// Rows go first so a failure between the two steps leaves orphan bytes
  /// (harmless, removed by the next purge) rather than rows referencing spill
  /// files that no longer exist.
  Future<void> purgeSession({required String sessionId}) async {
    await _chatHistoryDao.deleteSessionRows(sessionId: sessionId);
    await _attachmentSpillStorage.deleteSession(sessionId: sessionId);
    await _chatHistoryDao.reclaimFreedPages();
  }
}
