// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sesori_mcp_tool_arguments.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ListTasksArguments _$ListTasksArgumentsFromJson(Map json) =>
    _ListTasksArguments(projectId: json['project_id'] as String?);

_GetTaskArguments _$GetTaskArgumentsFromJson(Map json) =>
    _GetTaskArguments(taskId: json['task_id'] as String?);

_TaskIdArguments _$TaskIdArgumentsFromJson(Map json) =>
    _TaskIdArguments(taskId: json['task_id'] as String);

_GetTaskRunTranscriptArguments _$GetTaskRunTranscriptArgumentsFromJson(
  Map json,
) => _GetTaskRunTranscriptArguments(
  taskId: json['task_id'] as String,
  runId: json['run_id'] as String,
  page: (json['page'] as num?)?.toInt(),
);

_CreateTaskArguments _$CreateTaskArgumentsFromJson(Map json) =>
    _CreateTaskArguments(
      name: json['name'] as String,
      prompt: json['prompt'] as String,
      schedule: TaskSchedule.fromJson(
        Map<String, dynamic>.from(json['schedule'] as Map),
      ),
      timeZone: json['time_zone'] as String,
      projectId: json['project_id'] as String?,
      missedRunPolicy:
          $enumDecodeNullable(
            _$TaskMissedRunPolicyEnumMap,
            json['missed_run_policy'],
          ) ??
          TaskMissedRunPolicy.runWhenBack,
      runMode: json['run_mode'] == null
          ? const TaskRunMode.newSession()
          : TaskRunMode.fromJson(
              Map<String, dynamic>.from(json['run_mode'] as Map),
            ),
      model: json['model'] as String?,
      effort: json['effort'] as String?,
      approvalMode:
          $enumDecodeNullable(
            _$TaskApprovalModeEnumMap,
            json['approval_mode'],
          ) ??
          TaskApprovalMode.ask,
    );

const _$TaskMissedRunPolicyEnumMap = {
  TaskMissedRunPolicy.runWhenBack: 'runWhenBack',
  TaskMissedRunPolicy.waitForNext: 'waitForNext',
  TaskMissedRunPolicy.unknown: 'unknown',
};

const _$TaskApprovalModeEnumMap = {
  TaskApprovalMode.ask: 'ask',
  TaskApprovalMode.approveAll: 'approveAll',
  TaskApprovalMode.unknown: 'unknown',
};

_UpdateTaskArguments _$UpdateTaskArgumentsFromJson(Map json) =>
    _UpdateTaskArguments(
      taskId: json['task_id'] as String,
      name: json['name'] as String?,
      prompt: json['prompt'] as String?,
      commandArguments: json['command_arguments'] as String?,
      schedule: json['schedule'] == null
          ? null
          : TaskSchedule.fromJson(
              Map<String, dynamic>.from(json['schedule'] as Map),
            ),
      timeZone: json['time_zone'] as String?,
      missedRunPolicy: $enumDecodeNullable(
        _$TaskMissedRunPolicyEnumMap,
        json['missed_run_policy'],
      ),
      runMode: json['run_mode'] == null
          ? null
          : TaskRunMode.fromJson(
              Map<String, dynamic>.from(json['run_mode'] as Map),
            ),
      model: json['model'] as String?,
      effort: json['effort'] as String?,
      approvalMode: $enumDecodeNullable(
        _$TaskApprovalModeEnumMap,
        json['approval_mode'],
      ),
    );
