import "package:drift/drift.dart";
import "package:sesori_shared/sesori_shared.dart" show TaskRunFailureReason;

import "../database.dart";
import "../tables/scheduled_task_runs_table.dart";
import "../tables/scheduled_tasks_table.dart";
import "../tables/session_table.dart";

part "scheduled_task_dao.g.dart";

@DriftAccessor(tables: [ScheduledTasksTable, ScheduledTaskRunsTable, SessionTable])
class ScheduledTaskDao({required AppDatabase database})
    extends DatabaseAccessor<AppDatabase>
    with _$ScheduledTaskDaoMixin {
  this : super(database);

  /// Tasks not yet done, oldest first.
  Future<List<ScheduledTaskDto>> listUncompletedTasks() {
    return (select(scheduledTasksTable)
          ..where((row) => row.completedAt.isNull())
          ..orderBy([(row) => OrderingTerm.asc(row.createdAt), (row) => OrderingTerm.asc(row.id)]))
        .get();
  }

  Future<ScheduledTaskDto?> getTask({required String taskId}) {
    return (select(scheduledTasksTable)..where((row) => row.id.equals(taskId))).getSingleOrNull();
  }

  Future<ScheduledTaskDto> insertTask({required ScheduledTaskDto row}) {
    return into(scheduledTasksTable).insertReturning(row);
  }

  /// Writes [row]'s definition columns, next due time and update time, and
  /// clears the target session when [clearTarget] is set. The other bridge
  /// state is left alone, so a target a run wrote meanwhile survives, and a
  /// task completed meanwhile is not written. Returns the rows changed.
  Future<int> updateTaskDefinition({required ScheduledTaskDto row, required bool clearTarget}) {
    final changes = row
        .toCompanion(false)
        .copyWith(
          id: const Value.absent(),
          enabled: const Value.absent(),
          targetSessionId: clearTarget ? const Value(null) : const Value.absent(),
          completedAt: const Value.absent(),
          createdAt: const Value.absent(),
        );
    return (update(
      scheduledTasksTable,
    )..where((task) => task.id.equals(row.id) & task.completedAt.isNull())).write(changes);
  }

  /// Leaves completed tasks alone. Returns the rows changed.
  Future<int> setTaskEnabled({
    required String taskId,
    required bool enabled,
    required int? nextDueAt,
    required int updatedAt,
  }) {
    return (update(
      scheduledTasksTable,
    )..where((task) => task.id.equals(taskId) & task.completedAt.isNull())).write(
      ScheduledTasksTableCompanion(
        enabled: Value(enabled),
        nextDueAt: Value(nextDueAt),
        updatedAt: Value(updatedAt),
      ),
    );
  }

  /// Points tasks of merged-away projects at the project that absorbed them.
  Future<int> moveTasksToProject({required Set<String> fromProjectIds, required String toProjectId}) {
    return (update(scheduledTasksTable)..where((task) => task.projectId.isIn(fromProjectIds))).write(
      ScheduledTasksTableCompanion(projectId: Value(toProjectId)),
    );
  }

  Future<int> deleteTask({required String taskId}) {
    return (delete(scheduledTasksTable)..where((row) => row.id.equals(taskId))).go();
  }

  /// The runs of [taskIds], newest first.
  Future<List<ScheduledTaskRunDto>> listRunsForTasks({required Set<String> taskIds}) {
    return (select(scheduledTaskRunsTable)
          ..where((row) => row.taskId.isIn(taskIds))
          ..orderBy(_newestFirst))
        .get();
  }

  /// Inserts [row], then deletes its task's runs beyond the newest [keep],
  /// except the newest run with [alwaysKeepNewest], in one transaction.
  Future<void> insertRunAndTrim({
    required ScheduledTaskRunDto row,
    required int keep,
    required ScheduledTaskRunOutcomeKind alwaysKeepNewest,
  }) {
    return transaction(() async {
      await into(scheduledTaskRunsTable).insert(row);
      final taskRuns = scheduledTaskRunsTable;
      final newest = selectOnly(taskRuns)
        ..addColumns([taskRuns.id])
        ..where(taskRuns.taskId.equals(row.taskId))
        ..orderBy(_newestFirstColumns(taskRuns))
        ..limit(keep);
      final newestKept = selectOnly(taskRuns)
        ..addColumns([taskRuns.id])
        ..where(taskRuns.taskId.equals(row.taskId) & taskRuns.outcome.equalsValue(alwaysKeepNewest))
        ..orderBy(_newestFirstColumns(taskRuns))
        ..limit(1);
      await (delete(taskRuns)..where(
            (run) => run.taskId.equals(row.taskId) & run.id.isNotInQuery(newest) & run.id.isNotInQuery(newestKept),
          ))
          .go();
    });
  }

  /// Enabled tasks not yet done whose next due time is at or before [now].
  Future<List<ScheduledTaskDto>> listDueTasks({required int now}) {
    return (select(scheduledTasksTable)
          ..where(
            (row) => row.enabled.equals(true) & row.completedAt.isNull() & row.nextDueAt.isSmallerOrEqualValue(now),
          )
          ..orderBy([(row) => OrderingTerm.asc(row.nextDueAt), (row) => OrderingTerm.asc(row.id)]))
        .get();
  }

  /// In one transaction, and only while the task's update time is still
  /// [expectedUpdatedAt]: writes its next due time and completion time, then
  /// inserts [run] as [insertRunAndTrim] does. Returns whether it wrote.
  Future<bool> reserveRun({
    required String taskId,
    required int expectedUpdatedAt,
    required int? nextDueAt,
    required int? completedAt,
    required ScheduledTaskRunDto run,
    required int keep,
  }) {
    return transaction(() async {
      final changed =
          await (update(scheduledTasksTable)
                ..where((task) => task.id.equals(taskId) & task.updatedAt.equals(expectedUpdatedAt)))
              .write(ScheduledTasksTableCompanion(nextDueAt: Value(nextDueAt), completedAt: Value(completedAt)));
      if (changed == 0) return false;
      await insertRunAndTrim(row: run, keep: keep, alwaysKeepNewest: ScheduledTaskRunOutcomeKind.started);
      return true;
    });
  }

  /// The task's newest run whose prompt went out.
  Future<ScheduledTaskRunDto?> getLatestStartedRun({required String taskId}) {
    return (select(scheduledTaskRunsTable)
          ..where(
            (row) => row.taskId.equals(taskId) & row.outcome.equalsValue(ScheduledTaskRunOutcomeKind.started),
          )
          ..orderBy(_newestFirst)
          ..limit(1))
        .getSingleOrNull();
  }

  /// The task that started each of [sessionIds] that a task started, in one
  /// join.
  Future<List<({String sessionId, ScheduledTaskDto task})>> listTasksOfSessions({
    required Set<String> sessionIds,
  }) async {
    final query = select(sessionTable).join([
      innerJoin(scheduledTasksTable, scheduledTasksTable.id.equalsExp(sessionTable.scheduledTaskId)),
    ])..where(sessionTable.sessionId.isIn(sessionIds));
    return [
      for (final row in await query.get())
        (sessionId: row.readTable(sessionTable).sessionId, task: row.readTable(scheduledTasksTable)),
    ];
  }

  /// The newest run that went to [sessionId].
  Future<ScheduledTaskRunDto?> getLatestRunOfSession({required String sessionId}) {
    return (select(scheduledTaskRunsTable)
          ..where((row) => row.sessionId.equals(sessionId))
          ..orderBy(_newestFirst)
          ..limit(1))
        .getSingleOrNull();
  }

  /// Sets the user-prompted time of the newest run that went to [sessionId],
  /// unless it is already set. Returns the rows changed.
  Future<int> setLatestRunUserPromptedAt({required String sessionId, required int userPromptedAt}) {
    final taskRuns = scheduledTaskRunsTable;
    final latest = selectOnly(taskRuns)
      ..addColumns([taskRuns.id])
      ..where(taskRuns.sessionId.equals(sessionId))
      ..orderBy(_newestFirstColumns(taskRuns))
      ..limit(1);
    return (update(taskRuns)..where((run) => run.id.isInQuery(latest) & run.userPromptedAt.isNull())).write(
      ScheduledTaskRunsTableCompanion(userPromptedAt: Value(userPromptedAt)),
    );
  }

  /// Points the task at [sessionId], only while its update time is still
  /// [expectedUpdatedAt]. Returns the rows changed.
  Future<int> setTargetSession({required String taskId, required int expectedUpdatedAt, required String sessionId}) {
    return (update(scheduledTasksTable)
          ..where((task) => task.id.equals(taskId) & task.updatedAt.equals(expectedUpdatedAt)))
        .write(ScheduledTasksTableCompanion(targetSessionId: Value(sessionId)));
  }

  /// Returns the rows changed.
  Future<int> setRunSession({required String runId, required String sessionId}) {
    return (update(scheduledTaskRunsTable)..where((row) => row.id.equals(runId))).write(
      ScheduledTaskRunsTableCompanion(sessionId: Value(sessionId)),
    );
  }

  /// Returns the rows changed.
  Future<int> setRunCompactRequestedAt({required String runId, required int compactRequestedAt}) {
    return (update(scheduledTaskRunsTable)..where((row) => row.id.equals(runId))).write(
      ScheduledTaskRunsTableCompanion(compactRequestedAt: Value(compactRequestedAt)),
    );
  }

  /// Turns a started run into one that could not start. Returns the rows
  /// changed.
  Future<int> markRunFailed({required String runId, required TaskRunFailureReason reason}) {
    return (update(scheduledTaskRunsTable)..where((row) => row.id.equals(runId))).write(
      ScheduledTaskRunsTableCompanion(
        outcome: const Value(ScheduledTaskRunOutcomeKind.failed),
        reason: Value(reason),
        late: const Value(false),
      ),
    );
  }

  static List<OrderClauseGenerator<$ScheduledTaskRunsTableTable>> get _newestFirst => [
    (row) => OrderingTerm.desc(row.firedAt),
    (row) => OrderingTerm.desc(row.id),
  ];

  static List<OrderingTerm> _newestFirstColumns($ScheduledTaskRunsTableTable table) => [
    OrderingTerm.desc(table.firedAt),
    OrderingTerm.desc(table.id),
  ];
}
