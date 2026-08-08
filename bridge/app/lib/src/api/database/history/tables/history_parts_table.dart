import "package:drift/drift.dart";

/// One stored part of a chat message.
///
/// `partJson` holds the shared `MessagePart` wire model with inline attachment
/// bytes replaced by a spill-file reference (see `AttachmentSpillStorage`).
@TableIndex(name: "idx_history_parts_order", columns: {#sessionId, #messageId, #orderIndex})
class HistoryPartsTable extends Table {
  @override
  String get tableName => "history_parts";

  TextColumn get sessionId => text()();
  TextColumn get messageId => text()();
  TextColumn get partId => text()();
  IntColumn get orderIndex => integer()();
  TextColumn get partJson => text()();
  IntColumn get updatedAt => integer()();

  @override
  bool get withoutRowId => true;

  @override
  Set<Column> get primaryKey => {sessionId, messageId, partId};
}
