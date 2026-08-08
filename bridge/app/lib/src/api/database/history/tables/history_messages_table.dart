import "package:drift/drift.dart";

/// One stored chat message, keyed by its owning session.
///
/// `seq` is the per-session monotonic pagination cursor; `infoJson` holds the
/// shared `Message` wire model verbatim. No other wire field is extracted into
/// a column because the only queries are "by session, ordered, paged".
@TableIndex(name: "idx_history_messages_seq", columns: {#sessionId, #seq}, unique: true)
class HistoryMessagesTable extends Table {
  @override
  String get tableName => "history_messages";

  TextColumn get sessionId => text()();
  TextColumn get messageId => text()();
  IntColumn get seq => integer()();
  TextColumn get infoJson => text()();
  IntColumn get updatedAt => integer()();

  @override
  bool get withoutRowId => true;

  @override
  Set<Column> get primaryKey => {sessionId, messageId};
}
