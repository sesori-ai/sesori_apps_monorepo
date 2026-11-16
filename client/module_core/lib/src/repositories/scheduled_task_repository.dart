import "package:injectable/injectable.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../api/scheduled_task_api.dart";
import "models/scheduled_task_result.dart";

/// The current computer's scheduled tasks.
@lazySingleton
class ScheduledTaskRepository({required final ScheduledTaskApi _api}) {
  Future<ScheduledTaskResult<List<ScheduledTask>>> listTasks() async =>
      _resultOf(response: await _api.listTasks(), value: (data) => data.items);

  /// The task's run history, newest first.
  Future<ScheduledTaskResult<List<ScheduledTaskRun>>> listRuns({required String taskId}) async => _resultOf(
    response: await _api.listRuns(taskId: taskId),
    value: (data) => data.items,
  );

  Future<ScheduledTaskResult<ScheduledTask>> create({required ScheduledTaskDefinition definition}) async => _resultOf(
    response: await _api.create(definition: definition),
    value: (data) => data.task,
  );

  /// Replaces the task's definition; for renaming, the same definition under
  /// a new name.
  Future<ScheduledTaskResult<ScheduledTask>> update({
    required String taskId,
    required ScheduledTaskDefinition definition,
  }) async => _resultOf(
    response: await _api.update(taskId: taskId, definition: definition),
    value: (data) => data.task,
  );

  Future<ScheduledTaskResult<ScheduledTask>> setEnabled({required String taskId, required bool enabled}) async =>
      _resultOf(
        response: await _api.setEnabled(taskId: taskId, enabled: enabled),
        value: (data) => data.task,
      );

  Future<ScheduledTaskResult<void>> delete({required String taskId}) async => _resultOf(
    response: await _api.delete(taskId: taskId),
    value: (_) {},
  );

  Future<ScheduledTaskResult<ScheduledTaskRun>> runNow({required String taskId}) async => _resultOf(
    response: await _api.runNow(taskId: taskId),
    value: (data) => data.run,
  );

  static ScheduledTaskResult<T> _resultOf<R, T>({
    required ApiResponse<R> response,
    required T Function(R data) value,
  }) => switch (response) {
    SuccessResponse(:final data) => ScheduledTaskSuccess(value: value(data)),
    ErrorResponse(error: NonSuccessCodeError(:final rawErrorString) && final error) => switch (_errorCodeOf(
      rawErrorString: rawErrorString,
    )) {
      final code? => ScheduledTaskRefused(code: code),
      // An older bridge answers every task route with its router's bare 404.
      null when error.errorCode == 404 => ScheduledTaskBridgeOutdated<T>(),
      null => ScheduledTaskFailure(error: error),
    },
    ErrorResponse(:final error) => ScheduledTaskFailure(error: error),
  };

  /// The typed refusal in [rawErrorString], or null when the body is not one.
  static ScheduledTaskErrorCode? _errorCodeOf({required String? rawErrorString}) {
    if (rawErrorString == null) return null;
    try {
      return ScheduledTaskErrorResponse.fromJson(jsonDecodeMap(rawErrorString)).code;
    } on Object {
      // Not a task route's body: the bridge that answered does not know the route.
      return null;
    }
  }
}
