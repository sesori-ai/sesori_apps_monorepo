import "dart:math";

import "package:drift/drift.dart" show Value;
import "package:sesori_shared/sesori_shared.dart";

import "../api/database/daos/scheduled_task_dao.dart";
import "../api/database/database.dart";
import "mappers/scheduled_task_mapper.dart";
import "models/scheduled_task_record.dart";
import "random_hex_id.dart";

/// Stored tasks and their run history.
class ScheduledTaskRepository({required final ScheduledTaskDao _dao}) {
  /// History rows kept per task, beyond the newest started run.
  static const int runHistoryLimit = 20;
  static const _mapper = ScheduledTaskMapper();
  static final Random _secureRandom = Random.secure();

  /// Tasks not yet done, oldest first.
  Future<List<ScheduledTaskRecord>> listUncompleted() async => [
    for (final row in await _dao.listUncompletedTasks()) _mapper.recordFromDto(row: row),
  ];

  Future<ScheduledTaskRecord?> get({required String taskId}) async {
    final row = await _dao.getTask(taskId: taskId);
    return row == null ? null : _mapper.recordFromDto(row: row);
  }

  /// Stores a new enabled task.
  Future<ScheduledTaskRecord> create({
    required ScheduledTaskDefinition definition,
    required DateTime? nextDueAt,
    required DateTime now,
  }) async {
    final row = await _dao.insertTask(
      row: _mapper
          .definitionColumns(definition: definition)
          .copyWith(
            id: Value(generateRandomHexId(secureRandom: _secureRandom, prefix: "stk_", byteLength: 16)),
            enabled: const Value(true),
            nextDueAt: Value(nextDueAt?.millisecondsSinceEpoch),
            createdAt: Value(now.millisecondsSinceEpoch),
            updatedAt: Value(now.millisecondsSinceEpoch),
          ),
    );
    return _mapper.recordFromDto(row: row);
  }

  /// Replaces the task's definition and next due time, clearing its target
  /// session when [clearTarget] is set. Null when the task is gone.
  Future<ScheduledTaskRecord?> updateDefinition({
    required String taskId,
    required ScheduledTaskDefinition definition,
    required DateTime? nextDueAt,
    required bool clearTarget,
    required DateTime now,
  }) async {
    final changes = _mapper
        .definitionColumns(definition: definition)
        .copyWith(
          nextDueAt: Value(nextDueAt?.millisecondsSinceEpoch),
          targetSessionId: clearTarget ? const Value(null) : const Value.absent(),
          updatedAt: Value(now.millisecondsSinceEpoch),
        );
    return await _updateAndRead(taskId: taskId, changes: changes);
  }

  /// Null when the task is gone.
  Future<ScheduledTaskRecord?> setEnabled({
    required String taskId,
    required bool enabled,
    required DateTime? nextDueAt,
    required DateTime now,
  }) {
    return _updateAndRead(
      taskId: taskId,
      changes: ScheduledTasksTableCompanion(
        enabled: Value(enabled),
        nextDueAt: Value(nextDueAt?.millisecondsSinceEpoch),
        updatedAt: Value(now.millisecondsSinceEpoch),
      ),
    );
  }

  /// Deletes the task and its runs; its sessions become ordinary sessions.
  /// False when the task was already gone.
  Future<bool> delete({required String taskId}) async => await _dao.deleteTask(taskId: taskId) > 0;

  /// The newest run of each of [taskIds] that has one.
  Future<Map<String, ScheduledTaskRun>> latestRuns({required Set<String> taskIds}) async {
    final latest = <String, ScheduledTaskRun>{};
    for (final row in await _dao.listRunsForTasks(taskIds: taskIds)) {
      latest.putIfAbsent(row.taskId, () => _mapper.runFromDto(row: row));
    }
    return latest;
  }

  /// The task's run history, newest first.
  Future<List<ScheduledTaskRun>> listRuns({required String taskId}) async => [
    for (final row in await _dao.listRunsForTasks(taskIds: {taskId})) _mapper.runFromDto(row: row),
  ];

  /// Writes one history row and trims the task's history to the newest
  /// [runHistoryLimit] rows. The newest started run always stays, so a still
  /// running session is never hidden from the overlap check by later skips.
  Future<ScheduledTaskRun> recordRun({
    required String taskId,
    required ScheduledTaskInstant scheduledFor,
    required ScheduledTaskRunOutcome outcome,
    required DateTime firedAt,
  }) async {
    final row = _mapper.runToDto(
      id: generateRandomHexId(secureRandom: _secureRandom, prefix: "str_", byteLength: 16),
      taskId: taskId,
      scheduledFor: scheduledFor,
      outcome: outcome,
      firedAt: firedAt,
    );
    await _dao.insertRunAndTrim(row: row, keep: runHistoryLimit);
    return _mapper.runFromDto(row: row);
  }

  Future<ScheduledTaskRecord?> _updateAndRead({
    required String taskId,
    required ScheduledTasksTableCompanion changes,
  }) async {
    if (await _dao.updateTask(taskId: taskId, changes: changes) == 0) return null;
    return await get(taskId: taskId);
  }
}
