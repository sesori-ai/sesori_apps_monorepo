import "package:drift/drift.dart";
import "package:sesori_shared/sesori_shared.dart";

import "scheduled_tasks_table.dart";
import "session_table.dart";

enum ScheduledTaskRunOutcomeKind() {
  started,
  skipped,
  missed,
  failed,
}

/// A task's run history: ran, ran late, skipped, missed and couldn't start.
/// Trimmed per task when a row is written.
@DataClassName("ScheduledTaskRunDto")
@TableIndex(name: "idx_scheduled_task_runs_task", columns: {#taskId, #firedAt})
@TableIndex(name: "idx_scheduled_task_runs_session", columns: {#sessionId})
class ScheduledTaskRunsTable() extends Table {
  @override
  String get tableName => "scheduled_task_runs";

  TextColumn get id => text()();
  TextColumn get taskId => text().references(ScheduledTasksTable, #id, onDelete: KeyAction.cascade)();

  /// The session a started run sent its prompt to. Null for other outcomes,
  /// and once that session is deleted.
  TextColumn get sessionId => text().nullable().references(SessionTable, #sessionId, onDelete: KeyAction.setNull)();

  /// UTC milliseconds of the occurrence, or of the Run now tap.
  IntColumn get scheduledFor => integer()();

  /// The task zone's offset at [scheduledFor], frozen when written so a later
  /// zone edit keeps past rows.
  IntColumn get scheduledForOffsetMinutes => integer()();
  IntColumn get firedAt => integer()();
  TextColumn get outcome => textEnum<ScheduledTaskRunOutcomeKind>()();

  /// Set only for a failed run.
  TextColumn get reason => textEnum<TaskRunFailureReason>().nullable()();

  /// What a failed run tried to use, as JSON. Null for other outcomes and for
  /// failed runs recorded before the bridge kept it.
  TextColumn get attemptJson => text().nullable()();

  /// Set only for a started run.
  BoolColumn get late => boolean()();

  /// When the user first sent their own prompt into the run's session.
  IntColumn get userPromptedAt => integer().nullable()();

  /// When the bridge asked the run's session to compact.
  IntColumn get compactRequestedAt => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  bool get withoutRowId => true;
}
