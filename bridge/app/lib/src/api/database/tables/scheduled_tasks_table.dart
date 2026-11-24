import "package:drift/drift.dart";
import "package:sesori_shared/sesori_shared.dart";

import "session_table.dart";

/// Where each run of a task sends its prompt. Same-session tasks also store
/// their auto-compact switch, in [ScheduledTasksTable.autoCompact].
enum ScheduledTaskRunModeKind() {
  newSession,
  sameSession,
}

/// Tasks the bridge runs headlessly. The prompt, model and schedule are JSON
/// of their wire shapes; the bridge never stores a value it does not know.
@DataClassName("ScheduledTaskDto")
@TableIndex(name: "idx_scheduled_tasks_next_due", columns: {#nextDueAt})
class ScheduledTasksTable() extends Table {
  @override
  String get tableName => "scheduled_tasks";

  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get promptJson => text()();
  TextColumn get projectId => text()();
  TextColumn get pluginId => text()();
  TextColumn get agent => text().nullable()();
  TextColumn get modelJson => text().nullable()();
  TextColumn get variant => text().nullable()();
  BoolColumn get fastMode => boolean()();
  BoolColumn get dedicatedWorktree => boolean()();
  TextColumn get scheduleJson => text()();
  TextColumn get timeZone => text()();
  TextColumn get missedRunPolicy => textEnum<TaskMissedRunPolicy>()();
  TextColumn get runMode => textEnum<ScheduledTaskRunModeKind>()();
  BoolColumn get autoCompact => boolean()();
  TextColumn get approvalMode => textEnum<TaskApprovalMode>()();

  /// The shell command a run executes before its prompt, if any. Outside the
  /// definition JSON, because the app sends the definition whole.
  TextColumn get command => text().nullable()();
  BoolColumn get enabled => boolean()();

  /// UTC milliseconds of the next run. Null while paused or done.
  IntColumn get nextDueAt => integer().nullable()();

  /// The session a same-session task continues. Null until its first run, and
  /// again once that session is deleted or an edit moves the task elsewhere.
  TextColumn get targetSessionId =>
      text().nullable().references(SessionTable, #sessionId, onDelete: KeyAction.setNull)();

  /// When a one-off task ran. A done task leaves the list but keeps its row,
  /// so its session keeps the task's mark.
  IntColumn get completedAt => integer().nullable()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  bool get withoutRowId => true;
}
