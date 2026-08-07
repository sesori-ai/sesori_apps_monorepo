import "package:drift/drift.dart";

import "chat_history_database.dart";
import "tables/history_messages_table.dart";
import "tables/history_parts_table.dart";
import "tables/history_sync_state_table.dart";

part "chat_history_dao.g.dart";

@DriftAccessor(tables: [HistoryMessagesTable, HistoryPartsTable, HistorySyncStateTable])
class ChatHistoryDao extends DatabaseAccessor<ChatHistoryDatabase> with _$ChatHistoryDaoMixin {
  ChatHistoryDao(super.attachedDatabase);

  /// Removes every stored row for [sessionIds] in one transaction.
  ///
  /// Ids are chunked because each one becomes a bind variable and a session
  /// family is unbounded; SQLite would otherwise reject the statement for a
  /// large enough subtree.
  Future<void> deleteSessionRows({required List<String> sessionIds}) {
    if (sessionIds.isEmpty) return Future<void>.value();
    return transaction(() async {
      for (var start = 0; start < sessionIds.length; start += _maxBindVariables) {
        final chunk = sessionIds.sublist(
          start,
          start + _maxBindVariables > sessionIds.length ? sessionIds.length : start + _maxBindVariables,
        );
        await (delete(historyPartsTable)..where((table) => table.sessionId.isIn(chunk))).go();
        await (delete(historyMessagesTable)..where((table) => table.sessionId.isIn(chunk))).go();
        await (delete(historySyncStateTable)..where((table) => table.sessionId.isIn(chunk))).go();
      }
    });
  }

  /// Comfortably below SQLite's default `SQLITE_MAX_VARIABLE_NUMBER` (999 on
  /// older builds), which bounds how many ids one statement may carry.
  static const _maxBindVariables = 500;

  /// Returns freed pages to the filesystem after a purge.
  Future<void> reclaimFreedPages() => customStatement("PRAGMA incremental_vacuum");
}
