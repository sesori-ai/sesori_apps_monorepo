import "dart:async";

import "package:bloc/bloc.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../../capabilities/server_connection/connection_service.dart";
import "../../logging/logging.dart";
import "../../repositories/models/scheduled_task_editability.dart";
import "../../repositories/models/scheduled_task_result.dart";
import "../../repositories/scheduled_task_repository.dart";
import "scheduled_task_detail_state.dart";
import "scheduled_task_refresh.dart";

/// A task's own page: the task, its run history, and Run now, Pause/Resume,
/// Rename and Delete. Refreshed whenever the computer's tasks may have changed.
class ScheduledTaskDetailCubit({
  required final ScheduledTaskRepository _repository,
  required final ConnectionService _connectionService,
  required final String taskId,
}) extends Cubit<ScheduledTaskDetailState> {
  late final ScheduledTaskRefreshDispatcher _queue = ScheduledTaskRefreshDispatcher(refresh: _refresh);
  late final StreamSubscription<void> _signals;

  /// The task and its runs as the bridge last gave them; null until loaded.
  ({ScheduledTask task, List<ScheduledTaskRun> runs})? _shown;

  /// The pause or resume sent but not yet answered, shown over the task.
  /// Its [request] number tells each answer whether a newer tap followed.
  ({bool enabled, int request})? _pendingEnabled;
  int _switchRequests = 0;

  this : super(const ScheduledTaskDetailLoading()) {
    _signals = scheduledTaskRefreshSignals(connectionService: _connectionService).listen((_) => unawaited(refresh()));
    unawaited(refresh());
  }

  Future<void> refresh() => _queue.request();

  /// Shows the loading state again and reloads, after a failed first load.
  Future<void> retry() {
    emit(const ScheduledTaskDetailLoading());
    return refresh();
  }

  /// Starts a run now. The result says whether it started, could not start
  /// (the run's own outcome), or was refused, such as while the previous run
  /// is still going. The new run row arrives with the bridge's change event.
  Future<ScheduledTaskResult<ScheduledTaskRun>> runNow() async {
    final result = await _repository.runNow(taskId: taskId);
    logScheduledTaskFailure(message: "Run now for scheduled task $taskId did not start", result: result);
    return result;
  }

  /// Pauses or resumes the task. The page shows the change at once and
  /// reverts it when the bridge does not take it, returning false.
  Future<bool> setEnabled({required bool enabled}) async {
    final pending = (enabled: enabled, request: ++_switchRequests);
    _pendingEnabled = pending;
    _emitShown();
    final result = await _repository.setEnabled(taskId: taskId, enabled: enabled);
    if (isClosed) return false;
    logScheduledTaskFailure(message: "Failed to pause or resume scheduled task $taskId", result: result);
    // A newer tap owns the page until its own answer settles it, so this
    // older answer, whichever order it arrives in, changes nothing.
    if (_pendingEnabled != pending) return result is ScheduledTaskSuccess;
    _pendingEnabled = null;
    if (result case ScheduledTaskSuccess(:final value)) _replaceTask(task: value);
    _emitShown();
    return result is ScheduledTaskSuccess;
  }

  /// Renames the task, sending its definition back whole under [name]. Only
  /// offered for a task this app can edit.
  Future<bool> rename({required String name}) async {
    final shown = _shown;
    if (shown == null || !shown.task.definition.isEditableHere) return false;
    final result = await _repository.update(
      taskId: taskId,
      definition: shown.task.definition.copyWith(name: name),
    );
    if (isClosed) return false;
    logScheduledTaskFailure(message: "Failed to rename scheduled task $taskId", result: result);
    if (result case ScheduledTaskSuccess(:final value)) {
      _replaceTask(task: value);
      _emitShown();
    }
    return result is ScheduledTaskSuccess;
  }

  /// Deletes the task; its sessions stay as ordinary sessions. A task that is
  /// already gone counts as deleted.
  Future<bool> delete() async {
    final result = await _repository.delete(taskId: taskId);
    if (result case ScheduledTaskSuccess() || ScheduledTaskRefused(code: ScheduledTaskErrorCode.taskNotFound)) {
      return true;
    }
    logScheduledTaskFailure(message: "Failed to delete scheduled task $taskId", result: result);
    return false;
  }

  /// Whether a snapshot was applied; false keeps the page stale for a retry.
  Future<bool> _refresh() async {
    final ScheduledTaskResult<List<ScheduledTask>> tasks;
    final ScheduledTaskResult<List<ScheduledTaskRun>> runs;
    try {
      (tasks, runs) = await (_repository.listTasks(), _repository.listRuns(taskId: taskId)).wait;
    } on Object catch (error, stackTrace) {
      logw("Failed to load scheduled task $taskId", error, stackTrace);
      if (!isClosed && state is ScheduledTaskDetailLoading) emit(const ScheduledTaskDetailFailed());
      return false;
    }
    if (isClosed) return true;
    switch ((tasks, runs)) {
      case (ScheduledTaskSuccess(value: final tasks), ScheduledTaskSuccess(value: final runs)):
        final task = tasks.where((task) => task.id == taskId).firstOrNull;
        if (task == null) {
          _shown = null;
          emit(const ScheduledTaskDetailGone());
        } else {
          _shown = (task: task, runs: runs);
          _emitShown();
        }
        return true;
      case (ScheduledTaskBridgeOutdated(), _) || (_, ScheduledTaskBridgeOutdated()):
        emit(const ScheduledTaskDetailBridgeOutdated());
        return true;
      case (_, ScheduledTaskRefused(code: ScheduledTaskErrorCode.taskNotFound)):
        _shown = null;
        emit(const ScheduledTaskDetailGone());
        return true;
      case _:
        logScheduledTaskFailure(message: "Failed to load scheduled task $taskId", result: tasks);
        logScheduledTaskFailure(message: "Failed to load runs of scheduled task $taskId", result: runs);
        // What is already shown stays until a retry or the next signal.
        if (state is ScheduledTaskDetailLoading) emit(const ScheduledTaskDetailFailed());
        return false;
    }
  }

  void _replaceTask({required ScheduledTask task}) {
    if (_shown case (task: _, :final runs)) _shown = (task: task, runs: runs);
  }

  /// Emits the shown task with the pending pause or resume over it.
  void _emitShown() {
    final shown = _shown;
    if (isClosed || shown == null) return;
    final pending = _pendingEnabled;
    emit(
      ScheduledTaskDetailLoaded(
        task: pending == null ? shown.task : shown.task.copyWith(enabled: pending.enabled),
        runs: shown.runs,
        editable: shown.task.definition.isEditableHere,
      ),
    );
  }

  @override
  Future<void> close() async {
    _queue.dispose();
    await _signals.cancel();
    return await super.close();
  }
}
