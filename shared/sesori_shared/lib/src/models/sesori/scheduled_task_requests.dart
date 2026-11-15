import "package:freezed_annotation/freezed_annotation.dart";

import "scheduled_task.dart";

part "scheduled_task_requests.freezed.dart";
part "scheduled_task_requests.g.dart";

/// The computer's tasks, one-off tasks that already ran excluded.
@Freezed(fromJson: true, toJson: true)
sealed class ScheduledTaskListResponse with _$ScheduledTaskListResponse {
  const factory({required List<ScheduledTask> items}) = _ScheduledTaskListResponse;

  factory fromJson(Map<String, dynamic> json) => _$ScheduledTaskListResponseFromJson(json);
}

/// A new task starts enabled.
@Freezed(fromJson: true, toJson: true)
sealed class CreateScheduledTaskRequest with _$CreateScheduledTaskRequest {
  const factory({required ScheduledTaskDefinition definition}) = _CreateScheduledTaskRequest;

  factory fromJson(Map<String, dynamic> json) => _$CreateScheduledTaskRequestFromJson(json);
}

/// Replaces the task's whole definition. It changes future runs only.
@Freezed(fromJson: true, toJson: true)
sealed class UpdateScheduledTaskRequest with _$UpdateScheduledTaskRequest {
  const factory({
    required String taskId,
    required ScheduledTaskDefinition definition,
  }) = _UpdateScheduledTaskRequest;

  factory fromJson(Map<String, dynamic> json) => _$UpdateScheduledTaskRequestFromJson(json);
}

/// Pauses or resumes a task. Resuming never replays the paused period.
@Freezed(fromJson: true, toJson: true)
sealed class SetScheduledTaskEnabledRequest with _$SetScheduledTaskEnabledRequest {
  const factory({required String taskId, required bool enabled}) = _SetScheduledTaskEnabledRequest;

  factory fromJson(Map<String, dynamic> json) => _$SetScheduledTaskEnabledRequestFromJson(json);
}

/// Names one task, for deleting it, running it now or listing its runs.
@Freezed(fromJson: true, toJson: true)
sealed class ScheduledTaskIdRequest with _$ScheduledTaskIdRequest {
  const factory({required String taskId}) = _ScheduledTaskIdRequest;

  factory fromJson(Map<String, dynamic> json) => _$ScheduledTaskIdRequestFromJson(json);
}

/// The task as stored after a create, update or enabled change.
@Freezed(fromJson: true, toJson: true)
sealed class ScheduledTaskResponse with _$ScheduledTaskResponse {
  const factory({required ScheduledTask task}) = _ScheduledTaskResponse;

  factory fromJson(Map<String, dynamic> json) => _$ScheduledTaskResponseFromJson(json);
}

/// A task's run history, newest first.
@Freezed(fromJson: true, toJson: true)
sealed class ScheduledTaskRunListResponse with _$ScheduledTaskRunListResponse {
  const factory({required List<ScheduledTaskRun> items}) = _ScheduledTaskRunListResponse;

  factory fromJson(Map<String, dynamic> json) => _$ScheduledTaskRunListResponseFromJson(json);
}

/// The run that Run now wrote.
@Freezed(fromJson: true, toJson: true)
sealed class ScheduledTaskRunResponse with _$ScheduledTaskRunResponse {
  const factory({required ScheduledTaskRun run}) = _ScheduledTaskRunResponse;

  factory fromJson(Map<String, dynamic> json) => _$ScheduledTaskRunResponseFromJson(json);
}

enum ScheduledTaskErrorCode() {
  taskNotFound,
  emptyName,
  emptyPrompt,
  unknownProject,
  unknownHarness,
  unknownTimeZone,

  /// A date or time field is out of range, or a weekly schedule has no days.
  invalidSchedule,

  /// An every-hours interval outside 1 to 12.
  hoursOutOfRange,

  /// A one-off time that has already passed.
  onceTimeInPast,

  /// The definition holds a schedule, run mode, prompt or setting this bridge
  /// does not know, sent by a newer app.
  unsupportedByBridge,

  /// Run now refused because the previous run is still going.
  previousRunActive,
  unknown,
}

/// The body of a failed task request. Its presence tells a typed refusal apart
/// from the bare 404 an older bridge returns for the unknown route.
@Freezed(fromJson: true, toJson: true)
sealed class ScheduledTaskErrorResponse with _$ScheduledTaskErrorResponse {
  const factory({
    @JsonKey(unknownEnumValue: ScheduledTaskErrorCode.unknown) required ScheduledTaskErrorCode code,
  }) = _ScheduledTaskErrorResponse;

  factory fromJson(Map<String, dynamic> json) => _$ScheduledTaskErrorResponseFromJson(json);
}
