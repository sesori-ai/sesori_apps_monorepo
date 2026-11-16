import "dart:async";

import "package:bloc/bloc.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../../capabilities/server_connection/connection_service.dart";
import "../../logging/logging.dart";
import "../../repositories/models/scheduled_task_result.dart";
import "../../repositories/scheduled_task_repository.dart";
import "scheduled_task_refresh.dart";
import "scheduled_tasks_state.dart";

/// The Scheduled page: the computer's tasks, refreshed whenever they may have
/// changed, with on/off switches that move at once and revert on failure.
class ScheduledTasksCubit({
  required final ScheduledTaskRepository _repository,
  required final ConnectionService _connectionService,
}) extends Cubit<ScheduledTasksState> {
  late final ScheduledTaskRefreshDispatcher _queue = ScheduledTaskRefreshDispatcher(refresh: _refresh);
  late final StreamSubscription<void> _signals;

  /// The tasks as the bridge last listed them.
  List<ScheduledTask> _tasks = const [];

  /// Switch positions sent but not yet answered, by task id. They override
  /// [_tasks], so a refresh that lands meanwhile does not flick a switch back.
  final Map<String, bool> _pendingEnabled = {};

  this : super(const ScheduledTasksLoading()) {
    _signals = scheduledTaskRefreshSignals(connectionService: _connectionService).listen((_) => unawaited(refresh()));
    unawaited(refresh());
  }

  Future<void> refresh() => _queue.request();

  /// Shows the loading state again and reloads, after a failed first load.
  Future<void> retry() {
    emit(const ScheduledTasksLoading());
    return refresh();
  }

  /// Turns the task's schedule on or off. The switch moves at once; the
  /// bridge's answer decides where it ends, and false means it went back.
  Future<bool> setEnabled({required String taskId, required bool enabled}) async {
    _pendingEnabled[taskId] = enabled;
    _emitLoaded();
    final result = await _repository.setEnabled(taskId: taskId, enabled: enabled);
    if (isClosed) return false;
    if (result case ScheduledTaskSuccess(:final value)) {
      _tasks = [for (final task in _tasks) task.id == value.id ? value : task];
    } else {
      logScheduledTaskFailure(message: "Failed to turn scheduled task $taskId on or off", result: result);
    }
    // A newer tap owns the switch until its own answer settles it.
    if (_pendingEnabled[taskId] == enabled) _pendingEnabled.remove(taskId);
    _emitLoaded();
    return result is ScheduledTaskSuccess;
  }

  Future<void> _refresh() async {
    final ScheduledTaskResult<List<ScheduledTask>> result;
    try {
      result = await _repository.listTasks();
    } on Object catch (error, stackTrace) {
      logw("Failed to load scheduled tasks", error, stackTrace);
      if (!isClosed && state is ScheduledTasksLoading) emit(const ScheduledTasksFailed());
      return;
    }
    if (isClosed) return;
    switch (result) {
      case ScheduledTaskSuccess(:final value):
        _tasks = value;
        _emitLoaded();
      case ScheduledTaskBridgeOutdated():
        emit(const ScheduledTasksBridgeOutdated());
      case ScheduledTaskRefused() || ScheduledTaskFailure():
        logScheduledTaskFailure(message: "Failed to load scheduled tasks", result: result);
        // Tasks already shown stay; the next signal refreshes them.
        if (state is ScheduledTasksLoading) emit(const ScheduledTasksFailed());
    }
  }

  void _emitLoaded() {
    if (isClosed) return;
    final tasks = [
      for (final task in _tasks)
        switch (_pendingEnabled[task.id]) {
          final enabled? => task.copyWith(enabled: enabled),
          null => task,
        },
    ];
    emit(
      ScheduledTasksLoaded(
        recurring: [
          for (final task in tasks)
            if (task.definition.schedule is! TaskScheduleOnce) task,
        ],
        once: [
          for (final task in tasks)
            if (task.definition.schedule is TaskScheduleOnce) task,
        ]..sort(_soonestFirst),
      ),
    );
  }

  /// Orders one-off tasks by when they run; paused ones, with no time, last.
  static int _soonestFirst(ScheduledTask a, ScheduledTask b) => switch ((a.nextRunAt, b.nextRunAt)) {
    (final aAt?, final bAt?) => aAt.at.compareTo(bAt.at),
    (_?, null) => -1,
    (null, _?) => 1,
    (null, null) => 0,
  };

  @override
  Future<void> close() async {
    await _signals.cancel();
    return await super.close();
  }
}
