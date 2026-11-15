import "package:drift/drift.dart";

import "../database.dart";
import "../tables/scheduled_task_runs_table.dart";
import "../tables/scheduled_tasks_table.dart";

part "scheduled_task_dao.g.dart";

@DriftAccessor(tables: [ScheduledTasksTable, ScheduledTaskRunsTable])
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

  static List<OrderClauseGenerator<$ScheduledTaskRunsTableTable>> get _newestFirst => [
    (row) => OrderingTerm.desc(row.firedAt),
    (row) => OrderingTerm.desc(row.id),
  ];

  static List<OrderingTerm> _newestFirstColumns($ScheduledTaskRunsTableTable table) => [
    OrderingTerm.desc(table.firedAt),
    OrderingTerm.desc(table.id),
  ];
}
