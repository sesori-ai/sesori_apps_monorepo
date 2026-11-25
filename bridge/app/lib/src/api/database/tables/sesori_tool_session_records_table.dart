import "package:drift/drift.dart";

import "session_table.dart";

/// Records Sesori tool groups keep per session, such as a watched pull
/// request. A row goes with its session.
@DataClassName("SesoriToolSessionRecordDto")
@TableIndex(name: "idx_sesori_tool_session_records_session", columns: {#sessionId})
class SesoriToolSessionRecordsTable() extends Table {
  @override
  String get tableName => "sesori_tool_session_records";

  TextColumn get groupId => text()();
  TextColumn get sessionId => text().references(SessionTable, #sessionId, onDelete: KeyAction.cascade)();
  TextColumn get recordKey => text()();

  /// A JSON object in the group's own format.
  TextColumn get valueJson => text()();

  /// UTC milliseconds.
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {groupId, sessionId, recordKey};

  @override
  bool get withoutRowId => true;
}
