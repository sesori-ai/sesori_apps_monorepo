import "package:drift/drift.dart";

import "chat_history_database.dart";
import "tables/history_messages_table.dart";
import "tables/history_parts_table.dart";
import "tables/history_sync_state_table.dart";

part "chat_history_dao.g.dart";

@DriftAccessor(tables: [HistoryMessagesTable, HistoryPartsTable, HistorySyncStateTable])
class ChatHistoryDao extends DatabaseAccessor<ChatHistoryDatabase> with _$ChatHistoryDaoMixin {
  ChatHistoryDao(super.attachedDatabase);

  /// Removes every stored row for [sessionId] in one transaction.
  Future<void> deleteSessionRows({required String sessionId}) {
    return transaction(() async {
      await (delete(historyPartsTable)..where((table) => table.sessionId.equals(sessionId))).go();
      await (delete(historyMessagesTable)..where((table) => table.sessionId.equals(sessionId))).go();
      await (delete(historySyncStateTable)..where((table) => table.sessionId.equals(sessionId))).go();
    });
  }

  /// Returns freed pages to the filesystem after a purge.
  Future<void> reclaimFreedPages() => customStatement("PRAGMA incremental_vacuum");
}
