import "package:freezed_annotation/freezed_annotation.dart";
import "package:sesori_shared/sesori_shared.dart" show TaskApprovalMode, TaskMissedRunPolicy, TaskRunMode, TaskSchedule;

part "sesori_mcp_tool_arguments.freezed.dart";
part "sesori_mcp_tool_arguments.g.dart";

@Freezed(fromJson: true, toJson: false, copyWith: false, equal: false)
sealed class ListTasksArguments with _$ListTasksArguments {
  const factory({@JsonKey(name: "project_id") required String? projectId}) = _ListTasksArguments;

  factory fromJson(Map<String, dynamic> json) => _$ListTasksArgumentsFromJson(json);
}

@Freezed(fromJson: true, toJson: false, copyWith: false, equal: false)
sealed class GetTaskArguments with _$GetTaskArguments {
  const factory({@JsonKey(name: "task_id") required String? taskId}) = _GetTaskArguments;

  factory fromJson(Map<String, dynamic> json) => _$GetTaskArgumentsFromJson(json);
}

/// The arguments of the tools that take only a task.
@Freezed(fromJson: true, toJson: false, copyWith: false, equal: false)
sealed class TaskIdArguments with _$TaskIdArguments {
  const factory({@JsonKey(name: "task_id") required String taskId}) = _TaskIdArguments;

  factory fromJson(Map<String, dynamic> json) => _$TaskIdArgumentsFromJson(json);
}

@Freezed(fromJson: true, toJson: false, copyWith: false, equal: false)
sealed class GetTaskRunTranscriptArguments with _$GetTaskRunTranscriptArguments {
  const factory({
    @JsonKey(name: "task_id") required String taskId,
    @JsonKey(name: "run_id") required String runId,

    /// The previous page's `next_page`; null for the newest page.
    required int? page,
  }) = _GetTaskRunTranscriptArguments;

  factory fromJson(Map<String, dynamic> json) => _$GetTaskRunTranscriptArgumentsFromJson(json);
}

/// Structured fields use the task JSON the app sends; `model` is
/// `provider/model`.
@Freezed(fromJson: true, toJson: false, copyWith: false, equal: false)
sealed class CreateTaskArguments with _$CreateTaskArguments {
  const factory({
    required String name,
    required String prompt,
    required TaskSchedule schedule,
    @JsonKey(name: "time_zone") required String timeZone,

    /// Null for the caller's project.
    @JsonKey(name: "project_id") required String? projectId,
    @JsonKey(name: "missed_run_policy") @Default(TaskMissedRunPolicy.runWhenBack) TaskMissedRunPolicy missedRunPolicy,
    @JsonKey(name: "run_mode") @Default(TaskRunMode.newSession()) TaskRunMode runMode,
    required String? model,
    required String? effort,
    @JsonKey(name: "approval_mode") @Default(TaskApprovalMode.ask) TaskApprovalMode approvalMode,
  }) = _CreateTaskArguments;

  factory fromJson(Map<String, dynamic> json) => _$CreateTaskArgumentsFromJson(json);
}

/// Every field but the task is optional; a missing one keeps its value.
@Freezed(fromJson: true, toJson: false, copyWith: false, equal: false)
sealed class UpdateTaskArguments with _$UpdateTaskArguments {
  const factory({
    @JsonKey(name: "task_id") required String taskId,
    required String? name,
    required String? prompt,
    @JsonKey(name: "command_arguments") required String? commandArguments,
    required TaskSchedule? schedule,
    @JsonKey(name: "time_zone") required String? timeZone,
    @JsonKey(name: "missed_run_policy") required TaskMissedRunPolicy? missedRunPolicy,
    @JsonKey(name: "run_mode") required TaskRunMode? runMode,
    required String? model,
    required String? effort,
    @JsonKey(name: "approval_mode") required TaskApprovalMode? approvalMode,
  }) = _UpdateTaskArguments;

  factory fromJson(Map<String, dynamic> json) => _$UpdateTaskArgumentsFromJson(json);
}
