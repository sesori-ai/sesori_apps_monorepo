import "package:drift/drift.dart";

import "chat_history_database.dart";
import "tables/history_messages_table.dart";
import "tables/history_parts_table.dart";
import "tables/history_sync_state_table.dart";

part "chat_history_dao.g.dart";

@DriftAccessor(tables: [HistoryMessagesTable, HistoryPartsTable, HistorySyncStateTable])
class ChatHistoryDao extends DatabaseAccessor<ChatHistoryDatabase> with _$ChatHistoryDaoMixin {
  ChatHistoryDao(super.attachedDatabase);

  Future<HistorySyncStateTableData?> getSyncState({required String sessionId}) {
    return (select(historySyncStateTable)..where((table) => table.sessionId.equals(sessionId))).getSingleOrNull();
  }

  Future<List<HistoryMessagesTableData>> getMessages({required String sessionId}) {
    return (select(historyMessagesTable)
          ..where((table) => table.sessionId.equals(sessionId))
          ..orderBy([(table) => OrderingTerm(expression: table.seq)]))
        .get();
  }

  Future<List<HistoryPartsTableData>> getParts({required String sessionId}) {
    return (select(historyPartsTable)
          ..where((table) => table.sessionId.equals(sessionId))
          ..orderBy([
            (table) => OrderingTerm(expression: table.messageId),
            (table) => OrderingTerm(expression: table.orderIndex),
          ]))
        .get();
  }

  Future<int?> getMaxSeq({required String sessionId}) async {
    final maxSeq = historyMessagesTable.seq.max();
    final row = await (selectOnly(historyMessagesTable)
          ..addColumns([maxSeq])
          ..where(historyMessagesTable.sessionId.equals(sessionId)))
        .getSingle();
    return row.read(maxSeq);
  }

  Future<int?> getMessageSeq({required String sessionId, required String messageId}) async {
    final row =
        await (select(historyMessagesTable)..where(
              (table) => table.sessionId.equals(sessionId) & table.messageId.equals(messageId),
            ))
            .getSingleOrNull();
    return row?.seq;
  }

  Future<int?> getMaxPartOrderIndex({required String sessionId, required String messageId}) async {
    final maxOrder = historyPartsTable.orderIndex.max();
    final row = await (selectOnly(historyPartsTable)
          ..addColumns([maxOrder])
          ..where(historyPartsTable.sessionId.equals(sessionId) & historyPartsTable.messageId.equals(messageId)))
        .getSingle();
    return row.read(maxOrder);
  }

  Future<int?> getPartOrderIndex({
    required String sessionId,
    required String messageId,
    required String partId,
  }) async {
    final row =
        await (select(historyPartsTable)..where(
              (table) =>
                  table.sessionId.equals(sessionId) &
                  table.messageId.equals(messageId) &
                  table.partId.equals(partId),
            ))
            .getSingleOrNull();
    return row?.orderIndex;
  }

  Future<void> upsertMessage({required HistoryMessagesTableData row}) {
    return into(historyMessagesTable).insertOnConflictUpdate(row);
  }

  Future<void> upsertPart({required HistoryPartsTableData row}) {
    return into(historyPartsTable).insertOnConflictUpdate(row);
  }

  Future<void> deleteMessage({required String sessionId, required String messageId}) {
    return transaction(() async {
      await (delete(historyPartsTable)..where(
            (table) => table.sessionId.equals(sessionId) & table.messageId.equals(messageId),
          ))
          .go();
      await (delete(historyMessagesTable)..where(
            (table) => table.sessionId.equals(sessionId) & table.messageId.equals(messageId),
          ))
          .go();
    });
  }

  Future<void> deletePart({
    required String sessionId,
    required String messageId,
    required String partId,
  }) async {
    await (delete(historyPartsTable)..where(
          (table) =>
              table.sessionId.equals(sessionId) & table.messageId.equals(messageId) & table.partId.equals(partId),
        ))
        .go();
  }

  /// Replaces the session's transcript with [messages] and [parts], keeping
  /// the rows in [retainedMessageIds] that the transcript does not contain,
  /// and marks the session synced at [syncedAt] in the same transaction.
  ///
  /// One transaction so a crash can never leave a replaced transcript whose
  /// freshness marks describe the previous one. The freshness timestamps only
  /// ever move forward: capture that landed while the transcript was being
  /// fetched keeps its newer marks, so a backfill cannot rewind them.
  Future<void> replaceSessionRows({
    required String sessionId,
    required List<HistoryMessagesTableData> messages,
    required List<HistoryPartsTableData> parts,
    required Set<String> retainedMessageIds,
    required int watermark,
    required int backendActivityAt,
    required int syncedAt,
  }) {
    return transaction(() async {
      await (delete(historyPartsTable)..where(
            (table) => table.sessionId.equals(sessionId) & table.messageId.isNotIn(retainedMessageIds),
          ))
          .go();
      await (delete(historyMessagesTable)..where(
            (table) => table.sessionId.equals(sessionId) & table.messageId.isNotIn(retainedMessageIds),
          ))
          .go();
      // Retained rows still hold their pre-backfill `seq`, which the imported
      // numbering is about to reuse. Park them above every possible new value
      // first so the unique (session_id, seq) index never sees a collision
      // mid-transaction.
      await (update(historyMessagesTable)..where((table) => table.sessionId.equals(sessionId))).write(
        HistoryMessagesTableCompanion.custom(seq: historyMessagesTable.seq + const Constant(_seqParkingOffset)),
      );
      await batch((batch) {
        batch
          ..insertAllOnConflictUpdate(historyMessagesTable, messages)
          ..insertAllOnConflictUpdate(historyPartsTable, parts);
      });
      await _writeSyncState(
        sessionId: sessionId,
        watermark: watermark,
        backendActivityAt: backendActivityAt,
        syncedAt: Value(syncedAt),
      );
    });
  }

  /// Larger than any transcript a single session can hold, so parked rows
  /// cannot collide with the numbering being written beneath them.
  static const _seqParkingOffset = 1 << 40;

  /// Creates the row if absent, then advances its timestamps.
  Future<void> advanceSyncState({
    required String sessionId,
    required int watermark,
    required int backendActivityAt,
  }) {
    return _writeSyncState(
      sessionId: sessionId,
      watermark: watermark,
      backendActivityAt: backendActivityAt,
      syncedAt: const Value.absent(),
    );
  }

  /// Upserts the row, keeping whichever timestamps are later.
  ///
  /// `MAX` runs inside the statement so a concurrent writer cannot land
  /// between a read and a write and lose its marks.
  Future<void> _writeSyncState({
    required String sessionId,
    required int watermark,
    required int backendActivityAt,
    required Value<int?> syncedAt,
  }) async {
    await into(historySyncStateTable).insert(
      HistorySyncStateTableCompanion.insert(
        sessionId: sessionId,
        watermark: watermark,
        backendActivityAt: backendActivityAt,
        syncedAt: syncedAt,
      ),
      onConflict: DoUpdate(
        (old) => HistorySyncStateTableCompanion.custom(
          watermark: _greatest(old.watermark, Constant(watermark)),
          backendActivityAt: _greatest(old.backendActivityAt, Constant(backendActivityAt)),
          syncedAt: syncedAt.present ? Constant(syncedAt.value) : null,
        ),
      ),
    );
  }

  Expression<int> _greatest(Expression<int> left, Expression<int> right) =>
      FunctionCallExpression("MAX", [left, right]);

  Future<void> clearSyncedAt({required String sessionId}) async {
    await (update(historySyncStateTable)..where((table) => table.sessionId.equals(sessionId))).write(
      const HistorySyncStateTableCompanion(syncedAt: Value(null)),
    );
  }

  /// Every session id the store holds rows for.
  Future<Set<String>> getStoredSessionIds() async {
    final rows = await (selectOnly(historyMessagesTable, distinct: true)
          ..addColumns([historyMessagesTable.sessionId]))
        .get();
    final syncRows = await (selectOnly(historySyncStateTable, distinct: true)
          ..addColumns([historySyncStateTable.sessionId]))
        .get();
    return {
      for (final row in rows) row.read(historyMessagesTable.sessionId)!,
      for (final row in syncRows) row.read(historySyncStateTable.sessionId)!,
    };
  }

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
