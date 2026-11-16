import "dart:math";

import "package:sesori_shared/sesori_shared.dart";

import "../api/database/daos/scheduled_task_dao.dart";
import "../api/database/tables/scheduled_task_runs_table.dart";
import "mappers/scheduled_task_mapper.dart";
import "models/scheduled_task_record.dart";
import "random_hex_id.dart";

/// A task whose time has come, with the time it fell due.
typedef DueScheduledTask = ({ScheduledTaskRecord task, DateTime dueAt});

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
      row: _mapper.taskDto(
        id: generateRandomHexId(secureRandom: _secureRandom, prefix: "stk_", byteLength: 16),
        definition: definition,
        enabled: true,
        nextDueAt: nextDueAt?.millisecondsSinceEpoch,
        targetSessionId: null,
        completedAt: null,
        createdAt: now.millisecondsSinceEpoch,
        updatedAt: now.millisecondsSinceEpoch,
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
    final existing = await _dao.getTask(taskId: taskId);
    if (existing == null) return null;
    final row = _mapper.taskDto(
      id: taskId,
      definition: definition,
      enabled: existing.enabled,
      nextDueAt: nextDueAt?.millisecondsSinceEpoch,
      targetSessionId: existing.targetSessionId,
      completedAt: existing.completedAt,
      createdAt: existing.createdAt,
      updatedAt: now.millisecondsSinceEpoch,
    );
    if (await _dao.updateTaskDefinition(row: row, clearTarget: clearTarget) == 0) return null;
    return await get(taskId: taskId);
  }

  /// Null when the task is gone.
  Future<ScheduledTaskRecord?> setEnabled({
    required String taskId,
    required bool enabled,
    required DateTime? nextDueAt,
    required DateTime now,
  }) async {
    final changed = await _dao.setTaskEnabled(
      taskId: taskId,
      enabled: enabled,
      nextDueAt: nextDueAt?.millisecondsSinceEpoch,
      updatedAt: now.millisecondsSinceEpoch,
    );
    return changed == 0 ? null : await get(taskId: taskId);
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
    await _dao.insertRunAndTrim(
      row: row,
      keep: runHistoryLimit,
      alwaysKeepNewest: ScheduledTaskRunOutcomeKind.started,
    );
    return _mapper.runFromDto(row: row);
  }

  /// Enabled tasks not yet done that are due at [now], earliest first.
  Future<List<DueScheduledTask>> listDue({required DateTime now}) async => [
    for (final row in await _dao.listDueTasks(now: now.millisecondsSinceEpoch))
      if (row.nextDueAt case final dueAt?)
        (task: _mapper.recordFromDto(row: row), dueAt: DateTime.fromMillisecondsSinceEpoch(dueAt, isUtc: true)),
  ];

  /// Writes a fire's history row together with the task's advanced next due
  /// time and, for a one-off task, its completion, as [recordRun] trims. It
  /// writes nothing and returns null when the task was edited, paused or
  /// deleted since [task] was read, so that change wins.
  Future<ScheduledTaskRun?> reserveRun({
    required ScheduledTaskRecord task,
    required DateTime? nextDueAt,
    required DateTime? completedAt,
    required ScheduledTaskInstant scheduledFor,
    required ScheduledTaskRunOutcome outcome,
    required DateTime firedAt,
  }) async {
    final row = _mapper.runToDto(
      id: generateRandomHexId(secureRandom: _secureRandom, prefix: "str_", byteLength: 16),
      taskId: task.id,
      scheduledFor: scheduledFor,
      outcome: outcome,
      firedAt: firedAt,
    );
    final reserved = await _dao.reserveRun(
      taskId: task.id,
      expectedUpdatedAt: task.updatedAt.millisecondsSinceEpoch,
      nextDueAt: nextDueAt?.millisecondsSinceEpoch,
      completedAt: completedAt?.millisecondsSinceEpoch,
      run: row,
      keep: runHistoryLimit,
    );
    return reserved ? _mapper.runFromDto(row: row) : null;
  }

  /// The session of the task's newest run whose prompt went out, unless that
  /// session has been deleted. Skipped, missed and failed rows have none, so
  /// they never hide an earlier run that is still going.
  Future<String?> latestStartedSessionId({required String taskId}) async =>
      (await _dao.getLatestStartedRun(taskId: taskId))?.sessionId;

  /// Records the session a started run created. False when the run is gone
  /// with its deleted task.
  Future<bool> setRunSession({required String runId, required String sessionId}) async =>
      await _dao.setRunSession(runId: runId, sessionId: sessionId) > 0;

  /// False when the run is gone with its deleted task.
  Future<bool> markRunFailed({required String runId, required TaskRunFailureReason reason}) async =>
      await _dao.markRunFailed(runId: runId, reason: reason) > 0;
}
