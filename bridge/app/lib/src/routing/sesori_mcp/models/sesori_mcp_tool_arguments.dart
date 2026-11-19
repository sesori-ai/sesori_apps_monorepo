// Freezed forwards `@JsonSerializable` on a factory to the generated class.
// Checked decoding names the key that failed, so a tool error can name it.
// ignore_for_file: invalid_annotation_target

import "package:freezed_annotation/freezed_annotation.dart";
import "package:sesori_shared/sesori_shared.dart" show TaskApprovalMode, TaskMissedRunPolicy, TaskRunMode, TaskSchedule;

part "sesori_mcp_tool_arguments.freezed.dart";
part "sesori_mcp_tool_arguments.g.dart";

@Freezed(fromJson: true, toJson: false, copyWith: false, equal: false)
sealed class ListTasksArguments with _$ListTasksArguments {
  @JsonSerializable(checked: true)
  const factory({@JsonKey(name: "project_id") required String? projectId}) = _ListTasksArguments;

  factory fromJson(Map<String, dynamic> json) => _$ListTasksArgumentsFromJson(json);
}

@Freezed(fromJson: true, toJson: false, copyWith: false, equal: false)
sealed class GetTaskArguments with _$GetTaskArguments {
  @JsonSerializable(checked: true)
  const factory({@JsonKey(name: "task_id") required String? taskId}) = _GetTaskArguments;

  factory fromJson(Map<String, dynamic> json) => _$GetTaskArgumentsFromJson(json);
}

/// The arguments of the tools that take only a task.
@Freezed(fromJson: true, toJson: false, copyWith: false, equal: false)
sealed class TaskIdArguments with _$TaskIdArguments {
  @JsonSerializable(checked: true)
  const factory({@JsonKey(name: "task_id") required String taskId}) = _TaskIdArguments;

  factory fromJson(Map<String, dynamic> json) => _$TaskIdArgumentsFromJson(json);
}

@Freezed(fromJson: true, toJson: false, copyWith: false, equal: false)
sealed class GetTaskRunTranscriptArguments with _$GetTaskRunTranscriptArguments {
  @JsonSerializable(checked: true)
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
  @JsonSerializable(checked: true)
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
  @JsonSerializable(checked: true)
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

// The page arguments reject unknown fields, so a field the agent misspelled
// fails with its name instead of silently dropping content.

@Freezed(fromJson: true, toJson: false, copyWith: false, equal: false)
sealed class SendPageArguments with _$SendPageArguments {
  @JsonSerializable(checked: true, disallowUnrecognizedKeys: true, createToJson: false)
  const factory({
    required String title,
    required String? intro,
    required List<PageSectionArgument> sections,
  }) = _SendPageArguments;

  factory fromJson(Map<String, dynamic> json) => _$SendPageArgumentsFromJson(json);
}

@Freezed(fromJson: true, toJson: false, copyWith: false, equal: false)
sealed class PageSectionArgument with _$PageSectionArgument {
  @JsonSerializable(checked: true, disallowUnrecognizedKeys: true, createToJson: false)
  const factory({
    required String? heading,
    required String? body,
    required List<PageImageArgument>? images,
    required List<PageQuestionArgument>? questions,
  }) = _PageSectionArgument;

  factory fromJson(Map<String, dynamic> json) => _$PageSectionArgumentFromJson(json);
}

@Freezed(fromJson: true, toJson: false, copyWith: false, equal: false)
sealed class PageImageArgument with _$PageImageArgument {
  @JsonSerializable(checked: true, disallowUnrecognizedKeys: true, createToJson: false)
  const factory({required String path, required String? caption}) = _PageImageArgument;

  factory fromJson(Map<String, dynamic> json) => _$PageImageArgumentFromJson(json);
}

@Freezed(fromJson: true, toJson: false, copyWith: false, equal: false)
sealed class PageQuestionArgument with _$PageQuestionArgument {
  @JsonSerializable(checked: true, disallowUnrecognizedKeys: true, createToJson: false)
  const factory({
    required String id,
    required String title,
    required String? body,
    required List<PageImageArgument>? images,
    required PageQuestionKindArgument kind,

    /// Only for single and multiple; text questions take none.
    required List<PageOptionArgument>? options,
    @Default(false) bool required,
  }) = _PageQuestionArgument;

  factory fromJson(Map<String, dynamic> json) => _$PageQuestionArgumentFromJson(json);
}

enum PageQuestionKindArgument() {
  single,
  multiple,
  text,
}

@Freezed(fromJson: true, toJson: false, copyWith: false, equal: false)
sealed class PageOptionArgument with _$PageOptionArgument {
  @JsonSerializable(checked: true, disallowUnrecognizedKeys: true, createToJson: false)
  const factory({
    required String id,
    required String label,
    required String? description,
    required PageImageArgument? image,
    @Default(false) bool recommended,
  }) = _PageOptionArgument;

  factory fromJson(Map<String, dynamic> json) => _$PageOptionArgumentFromJson(json);
}
