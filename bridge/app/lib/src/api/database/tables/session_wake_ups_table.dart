import "package:drift/drift.dart";

import "session_table.dart";

/// How a wake-up's command was approved.
enum SessionWakeUpCommandApproval() {
  /// The user allowed it.
  allowed,

  /// Set while its session approved everything, so no one allowed it.
  byMode,
}

/// The wake-ups agents set: a prompt Sesori sends a session later, once or on
/// repeat. A row exists only while its wake-up is pending or repeating.
@DataClassName("SessionWakeUpDto")
@TableIndex(name: "idx_session_wake_ups_next_due", columns: {#nextDueAt})
@TableIndex(name: "idx_session_wake_ups_session", columns: {#sessionId})
class SessionWakeUpsTable() extends Table {
  @override
  String get tableName => "session_wake_ups";

  TextColumn get id => text()();

  /// The root session the wake-up is sent to.
  TextColumn get sessionId => text().references(SessionTable, #sessionId, onDelete: KeyAction.cascade)();
  TextColumn get label => text()();
  TextColumn get prompt => text()();

  /// The shell command run before the prompt is sent, if any.
  TextColumn get command => text().nullable()();

  /// Null exactly when [command] is.
  TextColumn get commandApproval => textEnum<SessionWakeUpCommandApproval>().nullable()();
  TextColumn get scheduleJson => text()();

  /// UTC milliseconds.
  IntColumn get nextDueAt => integer()();

  /// UTC milliseconds.
  IntColumn get createdAt => integer()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  bool get withoutRowId => true;
}
