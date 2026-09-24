import "package:drift/drift.dart";

import "session_table.dart";

@DataClassName("SessionContinuationDto")
class SessionContinuationTable() extends Table {
  @override
  String get tableName => "session_continuations";

  TextColumn get sessionId => text().references(SessionTable, #sessionId, onDelete: KeyAction.cascade)();
  BoolColumn get enabled => boolean()();
  TextColumn get outcomeJson => text()();

  @override
  Set<Column> get primaryKey => {sessionId};

  @override
  bool get withoutRowId => true;
}
