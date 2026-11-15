import "package:drift/drift.dart";

import "session_table.dart";

/// Answered side questions. A side chat is the group of rows sharing a
/// [sideChatId]; there is no separate chat table. Only successful exchanges
/// are written, once, after the answer arrives.
@DataClassName("SideChatExchangeDto")
@TableIndex(
  name: "idx_side_chat_exchanges_session",
  columns: {#sessionId, #sideChatId, #answeredAt},
)
class SideChatExchangesTable() extends Table {
  @override
  String get tableName => "side_chat_exchanges";

  TextColumn get id => text()();
  TextColumn get sessionId => text().references(SessionTable, #sessionId, onDelete: KeyAction.cascade)();
  TextColumn get sideChatId => text()();
  TextColumn get question => text()();
  TextColumn get answer => text()();
  TextColumn get answerNotice => text().nullable()();
  IntColumn get askedAt => integer()();
  IntColumn get answeredAt => integer()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  bool get withoutRowId => true;
}
