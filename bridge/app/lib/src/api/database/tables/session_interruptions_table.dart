import "package:drift/drift.dart";

import "session_table.dart";

/// The latest turn of each session that a bridge stop cut off.
@DataClassName("SessionInterruptionDto")
class SessionInterruptionsTable() extends Table {
  @override
  String get tableName => "session_interruptions";

  TextColumn get sessionId => text().references(SessionTable, #sessionId, onDelete: KeyAction.cascade)();

  /// The newest stored history message when the interruption was recorded.
  TextColumn get afterMessageId => text()();

  /// Whether the user opened the session or sent to it since.
  BoolColumn get acknowledged => boolean()();

  @override
  Set<Column> get primaryKey => {sessionId};

  @override
  bool get withoutRowId => true;
}
