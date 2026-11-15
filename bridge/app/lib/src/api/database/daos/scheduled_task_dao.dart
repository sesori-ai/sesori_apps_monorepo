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

  Future<ScheduledTaskDto> insertTask({required ScheduledTasksTableCompanion row}) {
    return into(scheduledTasksTable).insertReturning(row);
  }

  /// Writes only the present fields of [changes]; returns the rows changed.
  Future<int> updateTask({required String taskId, required ScheduledTasksTableCompanion changes}) {
    return (update(scheduledTasksTable)..where((row) => row.id.equals(taskId))).write(changes);
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
  /// except the newest started run, in one transaction.
  Future<void> insertRunAndTrim({required ScheduledTaskRunDto row, required int keep}) {
    return transaction(() async {
      await into(scheduledTaskRunsTable).insert(row);
      final taskRuns = scheduledTaskRunsTable;
      final newest = selectOnly(taskRuns)
        ..addColumns([taskRuns.id])
        ..where(taskRuns.taskId.equals(row.taskId))
        ..orderBy(_newestFirstColumns(taskRuns))
        ..limit(keep);
      final newestStarted = selectOnly(taskRuns)
        ..addColumns([taskRuns.id])
        ..where(taskRuns.taskId.equals(row.taskId) & taskRuns.outcome.equalsValue(ScheduledTaskRunOutcomeKind.started))
        ..orderBy(_newestFirstColumns(taskRuns))
        ..limit(1);
      await (delete(taskRuns)..where(
            (run) => run.taskId.equals(row.taskId) & run.id.isNotInQuery(newest) & run.id.isNotInQuery(newestStarted),
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
