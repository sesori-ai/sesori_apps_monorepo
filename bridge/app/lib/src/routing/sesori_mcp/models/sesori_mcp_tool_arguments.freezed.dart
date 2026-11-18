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
@JsonSerializable(createToJson: false)

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
@JsonSerializable(createToJson: false)

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
@JsonSerializable(createToJson: false)

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
@JsonSerializable(createToJson: false)

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




// dart format on
