import "package:injectable/injectable.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_shared/sesori_shared.dart";

import "client/relay_http_client.dart";

/// The bridge's scheduled-task routes. A bridge that predates them answers
/// each with a bare 404; a refusal carries a [ScheduledTaskErrorResponse].
@lazySingleton
class ScheduledTaskApi({required final RelayHttpApiClient _client}) {
  Future<ApiResponse<ScheduledTaskListResponse>> listTasks() =>
      _client.get("/scheduled-tasks", fromJson: ScheduledTaskListResponse.fromJson);

  Future<ApiResponse<ScheduledTaskRunListResponse>> listRuns({required String taskId}) => _client.post(
    "/scheduled-task/runs",
    body: ScheduledTaskIdRequest(taskId: taskId),
    fromJson: ScheduledTaskRunListResponse.fromJson,
  );

  Future<ApiResponse<ScheduledTaskResponse>> create({required ScheduledTaskDefinition definition}) => _client.post(
    "/scheduled-task/create",
    body: CreateScheduledTaskRequest(definition: definition),
    fromJson: ScheduledTaskResponse.fromJson,
  );

  Future<ApiResponse<ScheduledTaskResponse>> update({
    required String taskId,
    required ScheduledTaskDefinition definition,
  }) => _client.post(
    "/scheduled-task/update",
    body: UpdateScheduledTaskRequest(taskId: taskId, definition: definition),
    fromJson: ScheduledTaskResponse.fromJson,
  );

  Future<ApiResponse<ScheduledTaskResponse>> setEnabled({required String taskId, required bool enabled}) =>
      _client.patch(
        "/scheduled-task/enabled",
        body: SetScheduledTaskEnabledRequest(taskId: taskId, enabled: enabled),
        fromJson: ScheduledTaskResponse.fromJson,
      );

  Future<ApiResponse<SuccessEmptyResponse>> delete({required String taskId}) => _client.delete(
    "/scheduled-task/delete",
    body: ScheduledTaskIdRequest(taskId: taskId),
    fromJson: SuccessEmptyResponse.fromJson,
  );

  Future<ApiResponse<ScheduledTaskRunResponse>> runNow({required String taskId}) => _client.post(
    "/scheduled-task/run-now",
    body: ScheduledTaskIdRequest(taskId: taskId),
    fromJson: ScheduledTaskRunResponse.fromJson,
    // The bridge answers once the run's session has started, which can mean a
    // cold harness or a new worktree, like creating a session.
    timeout: _runNowTimeout,
  );

  static const Duration _runNowTimeout = Duration(seconds: 180);
}
