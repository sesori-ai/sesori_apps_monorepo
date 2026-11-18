// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sesori_mcp_tool_arguments.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ListTasksArguments _$ListTasksArgumentsFromJson(Map json) =>
    _ListTasksArguments(projectId: json['project_id'] as String?);

_GetTaskArguments _$GetTaskArgumentsFromJson(Map json) =>
    _GetTaskArguments(taskId: json['task_id'] as String?);

_ListTaskRunsArguments _$ListTaskRunsArgumentsFromJson(Map json) =>
    _ListTaskRunsArguments(taskId: json['task_id'] as String);

_GetTaskRunTranscriptArguments _$GetTaskRunTranscriptArgumentsFromJson(
  Map json,
) => _GetTaskRunTranscriptArguments(
  taskId: json['task_id'] as String,
  runId: json['run_id'] as String,
  page: (json['page'] as num?)?.toInt(),
);
