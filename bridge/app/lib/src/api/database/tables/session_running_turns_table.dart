import "package:drift/drift.dart";

import "session_table.dart";

/// Sessions with a turn in flight, so a bridge that stops without seeing the
/// turn end can tell on its next start that the turn was cut off.
@DataClassName("SessionRunningTurnDto")
class SessionRunningTurnsTable() extends Table {
  @override
  String get tableName => "session_running_turns";

  TextColumn get sessionId => text().references(SessionTable, #sessionId, onDelete: KeyAction.cascade)();

  /// UTC milliseconds of when this bridge run last saw the turn running, or
  /// adopted it from an earlier run. Every busy status re-stamps it.
  IntColumn get startedAt => integer()();

  @override
  Set<Column> get primaryKey => {sessionId};

  @override
  bool get withoutRowId => true;
}
