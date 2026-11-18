// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'sesori_mcp_tool_arguments.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ListTasksArguments {

@JsonKey(name: "project_id") String? get projectId;





@override
String toString() {
  final _this = this as ListTasksArguments;
  return 'ListTasksArguments(projectId: ${_this.projectId})';
}


}





/// @nodoc

@JsonSerializable(checked: true)
class _ListTasksArguments implements ListTasksArguments {
  const _ListTasksArguments({@JsonKey(name: "project_id") required this.projectId});
  factory _ListTasksArguments.fromJson(Map<String, dynamic> json) => _$ListTasksArgumentsFromJson(json);

@override@JsonKey(name: "project_id") final  String? projectId;






@override
String toString() {
    return 'ListTasksArguments(projectId: $projectId)';
}


}





/// @nodoc
mixin _$GetTaskArguments {

@JsonKey(name: "task_id") String? get taskId;





@override
String toString() {
  final _this = this as GetTaskArguments;
  return 'GetTaskArguments(taskId: ${_this.taskId})';
}


}





/// @nodoc

@JsonSerializable(checked: true)
class _GetTaskArguments implements GetTaskArguments {
  const _GetTaskArguments({@JsonKey(name: "task_id") required this.taskId});
  factory _GetTaskArguments.fromJson(Map<String, dynamic> json) => _$GetTaskArgumentsFromJson(json);

@override@JsonKey(name: "task_id") final  String? taskId;






@override
String toString() {
    return 'GetTaskArguments(taskId: $taskId)';
}


}





/// @nodoc
mixin _$TaskIdArguments {

@JsonKey(name: "task_id") String get taskId;





@override
String toString() {
  final _this = this as TaskIdArguments;
  return 'TaskIdArguments(taskId: ${_this.taskId})';
}


}





/// @nodoc

@JsonSerializable(checked: true)
class _TaskIdArguments implements TaskIdArguments {
  const _TaskIdArguments({@JsonKey(name: "task_id") required this.taskId});
  factory _TaskIdArguments.fromJson(Map<String, dynamic> json) => _$TaskIdArgumentsFromJson(json);

@override@JsonKey(name: "task_id") final  String taskId;






@override
String toString() {
    return 'TaskIdArguments(taskId: $taskId)';
}


}





/// @nodoc
mixin _$GetTaskRunTranscriptArguments {

@JsonKey(name: "task_id") String get taskId;@JsonKey(name: "run_id") String get runId;/// The previous page's `next_page`; null for the newest page.
 int? get page;





@override
String toString() {
  final _this = this as GetTaskRunTranscriptArguments;
  return 'GetTaskRunTranscriptArguments(taskId: ${_this.taskId}, runId: ${_this.runId}, page: ${_this.page})';
}


}





/// @nodoc

@JsonSerializable(checked: true)
class _GetTaskRunTranscriptArguments implements GetTaskRunTranscriptArguments {
  const _GetTaskRunTranscriptArguments({@JsonKey(name: "task_id") required this.taskId, @JsonKey(name: "run_id") required this.runId, required this.page});
  factory _GetTaskRunTranscriptArguments.fromJson(Map<String, dynamic> json) => _$GetTaskRunTranscriptArgumentsFromJson(json);

@override@JsonKey(name: "task_id") final  String taskId;
@override@JsonKey(name: "run_id") final  String runId;
/// The previous page's `next_page`; null for the newest page.
@override final  int? page;






@override
String toString() {
    return 'GetTaskRunTranscriptArguments(taskId: $taskId, runId: $runId, page: $page)';
}


}





/// @nodoc
mixin _$CreateTaskArguments {

 String get name; String get prompt; TaskSchedule get schedule;@JsonKey(name: "time_zone") String get timeZone;/// Null for the caller's project.
@JsonKey(name: "project_id") String? get projectId;@JsonKey(name: "missed_run_policy") TaskMissedRunPolicy get missedRunPolicy;@JsonKey(name: "run_mode") TaskRunMode get runMode; String? get model; String? get effort;@JsonKey(name: "approval_mode") TaskApprovalMode get approvalMode;





@override
String toString() {
  final _this = this as CreateTaskArguments;
  return 'CreateTaskArguments(name: ${_this.name}, prompt: ${_this.prompt}, schedule: ${_this.schedule}, timeZone: ${_this.timeZone}, projectId: ${_this.projectId}, missedRunPolicy: ${_this.missedRunPolicy}, runMode: ${_this.runMode}, model: ${_this.model}, effort: ${_this.effort}, approvalMode: ${_this.approvalMode})';
}


}





/// @nodoc

@JsonSerializable(checked: true)
class _CreateTaskArguments implements CreateTaskArguments {
  const _CreateTaskArguments({required this.name, required this.prompt, required this.schedule, @JsonKey(name: "time_zone") required this.timeZone, @JsonKey(name: "project_id") required this.projectId, @JsonKey(name: "missed_run_policy") this.missedRunPolicy = TaskMissedRunPolicy.runWhenBack, @JsonKey(name: "run_mode") this.runMode = const TaskRunMode.newSession(), required this.model, required this.effort, @JsonKey(name: "approval_mode") this.approvalMode = TaskApprovalMode.ask});
  factory _CreateTaskArguments.fromJson(Map<String, dynamic> json) => _$CreateTaskArgumentsFromJson(json);

@override final  String name;
@override final  String prompt;
@override final  TaskSchedule schedule;
@override@JsonKey(name: "time_zone") final  String timeZone;
/// Null for the caller's project.
@override@JsonKey(name: "project_id") final  String? projectId;
@override@JsonKey(name: "missed_run_policy") final  TaskMissedRunPolicy missedRunPolicy;
@override@JsonKey(name: "run_mode") final  TaskRunMode runMode;
@override final  String? model;
@override final  String? effort;
@override@JsonKey(name: "approval_mode") final  TaskApprovalMode approvalMode;






@override
String toString() {
    return 'CreateTaskArguments(name: $name, prompt: $prompt, schedule: $schedule, timeZone: $timeZone, projectId: $projectId, missedRunPolicy: $missedRunPolicy, runMode: $runMode, model: $model, effort: $effort, approvalMode: $approvalMode)';
}


}





/// @nodoc
mixin _$UpdateTaskArguments {

@JsonKey(name: "task_id") String get taskId; String? get name; String? get prompt;@JsonKey(name: "command_arguments") String? get commandArguments; TaskSchedule? get schedule;@JsonKey(name: "time_zone") String? get timeZone;@JsonKey(name: "missed_run_policy") TaskMissedRunPolicy? get missedRunPolicy;@JsonKey(name: "run_mode") TaskRunMode? get runMode; String? get model; String? get effort;@JsonKey(name: "approval_mode") TaskApprovalMode? get approvalMode;





@override
String toString() {
  final _this = this as UpdateTaskArguments;
  return 'UpdateTaskArguments(taskId: ${_this.taskId}, name: ${_this.name}, prompt: ${_this.prompt}, commandArguments: ${_this.commandArguments}, schedule: ${_this.schedule}, timeZone: ${_this.timeZone}, missedRunPolicy: ${_this.missedRunPolicy}, runMode: ${_this.runMode}, model: ${_this.model}, effort: ${_this.effort}, approvalMode: ${_this.approvalMode})';
}


}





/// @nodoc

@JsonSerializable(checked: true)
class _UpdateTaskArguments implements UpdateTaskArguments {
  const _UpdateTaskArguments({@JsonKey(name: "task_id") required this.taskId, required this.name, required this.prompt, @JsonKey(name: "command_arguments") required this.commandArguments, required this.schedule, @JsonKey(name: "time_zone") required this.timeZone, @JsonKey(name: "missed_run_policy") required this.missedRunPolicy, @JsonKey(name: "run_mode") required this.runMode, required this.model, required this.effort, @JsonKey(name: "approval_mode") required this.approvalMode});
  factory _UpdateTaskArguments.fromJson(Map<String, dynamic> json) => _$UpdateTaskArgumentsFromJson(json);

@override@JsonKey(name: "task_id") final  String taskId;
@override final  String? name;
@override final  String? prompt;
@override@JsonKey(name: "command_arguments") final  String? commandArguments;
@override final  TaskSchedule? schedule;
@override@JsonKey(name: "time_zone") final  String? timeZone;
@override@JsonKey(name: "missed_run_policy") final  TaskMissedRunPolicy? missedRunPolicy;
@override@JsonKey(name: "run_mode") final  TaskRunMode? runMode;
@override final  String? model;
@override final  String? effort;
@override@JsonKey(name: "approval_mode") final  TaskApprovalMode? approvalMode;






@override
String toString() {
    return 'UpdateTaskArguments(taskId: $taskId, name: $name, prompt: $prompt, commandArguments: $commandArguments, schedule: $schedule, timeZone: $timeZone, missedRunPolicy: $missedRunPolicy, runMode: $runMode, model: $model, effort: $effort, approvalMode: $approvalMode)';
}


}




// dart format on
