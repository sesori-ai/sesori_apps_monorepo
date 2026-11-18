// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sesori_mcp_tool_arguments.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ListTasksArguments _$ListTasksArgumentsFromJson(Map json) =>
    $checkedCreate('_ListTasksArguments', json, ($checkedConvert) {
      final val = _ListTasksArguments(
        projectId: $checkedConvert('project_id', (v) => v as String?),
      );
      return val;
    }, fieldKeyMap: const {'projectId': 'project_id'});

Map<String, dynamic> _$ListTasksArgumentsToJson(_ListTasksArguments instance) =>
    <String, dynamic>{'project_id': ?instance.projectId};

_GetTaskArguments _$GetTaskArgumentsFromJson(Map json) =>
    $checkedCreate('_GetTaskArguments', json, ($checkedConvert) {
      final val = _GetTaskArguments(
        taskId: $checkedConvert('task_id', (v) => v as String?),
      );
      return val;
    }, fieldKeyMap: const {'taskId': 'task_id'});

Map<String, dynamic> _$GetTaskArgumentsToJson(_GetTaskArguments instance) =>
    <String, dynamic>{'task_id': ?instance.taskId};

_TaskIdArguments _$TaskIdArgumentsFromJson(Map json) =>
    $checkedCreate('_TaskIdArguments', json, ($checkedConvert) {
      final val = _TaskIdArguments(
        taskId: $checkedConvert('task_id', (v) => v as String),
      );
      return val;
    }, fieldKeyMap: const {'taskId': 'task_id'});

Map<String, dynamic> _$TaskIdArgumentsToJson(_TaskIdArguments instance) =>
    <String, dynamic>{'task_id': instance.taskId};

_GetTaskRunTranscriptArguments _$GetTaskRunTranscriptArgumentsFromJson(
  Map json,
) => $checkedCreate('_GetTaskRunTranscriptArguments', json, ($checkedConvert) {
  final val = _GetTaskRunTranscriptArguments(
    taskId: $checkedConvert('task_id', (v) => v as String),
    runId: $checkedConvert('run_id', (v) => v as String),
    page: $checkedConvert('page', (v) => (v as num?)?.toInt()),
  );
  return val;
}, fieldKeyMap: const {'taskId': 'task_id', 'runId': 'run_id'});

Map<String, dynamic> _$GetTaskRunTranscriptArgumentsToJson(
  _GetTaskRunTranscriptArguments instance,
) => <String, dynamic>{
  'task_id': instance.taskId,
  'run_id': instance.runId,
  'page': ?instance.page,
};

_CreateTaskArguments _$CreateTaskArgumentsFromJson(Map json) => $checkedCreate(
  '_CreateTaskArguments',
  json,
  ($checkedConvert) {
    final val = _CreateTaskArguments(
      name: $checkedConvert('name', (v) => v as String),
      prompt: $checkedConvert('prompt', (v) => v as String),
      schedule: $checkedConvert(
        'schedule',
        (v) => TaskSchedule.fromJson(Map<String, dynamic>.from(v as Map)),
      ),
      timeZone: $checkedConvert('time_zone', (v) => v as String),
      projectId: $checkedConvert('project_id', (v) => v as String?),
      missedRunPolicy: $checkedConvert(
        'missed_run_policy',
        (v) =>
            $enumDecodeNullable(_$TaskMissedRunPolicyEnumMap, v) ??
            TaskMissedRunPolicy.runWhenBack,
      ),
      runMode: $checkedConvert(
        'run_mode',
        (v) => v == null
            ? const TaskRunMode.newSession()
            : TaskRunMode.fromJson(Map<String, dynamic>.from(v as Map)),
      ),
      model: $checkedConvert('model', (v) => v as String?),
      effort: $checkedConvert('effort', (v) => v as String?),
      approvalMode: $checkedConvert(
        'approval_mode',
        (v) =>
            $enumDecodeNullable(_$TaskApprovalModeEnumMap, v) ??
            TaskApprovalMode.ask,
      ),
    );
    return val;
  },
  fieldKeyMap: const {
    'timeZone': 'time_zone',
    'projectId': 'project_id',
    'missedRunPolicy': 'missed_run_policy',
    'runMode': 'run_mode',
    'approvalMode': 'approval_mode',
  },
);

Map<String, dynamic> _$CreateTaskArgumentsToJson(
  _CreateTaskArguments instance,
) => <String, dynamic>{
  'name': instance.name,
  'prompt': instance.prompt,
  'schedule': instance.schedule.toJson(),
  'time_zone': instance.timeZone,
  'project_id': ?instance.projectId,
  'missed_run_policy': _$TaskMissedRunPolicyEnumMap[instance.missedRunPolicy]!,
  'run_mode': instance.runMode.toJson(),
  'model': ?instance.model,
  'effort': ?instance.effort,
  'approval_mode': _$TaskApprovalModeEnumMap[instance.approvalMode]!,
};

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

_UpdateTaskArguments _$UpdateTaskArgumentsFromJson(Map json) => $checkedCreate(
  '_UpdateTaskArguments',
  json,
  ($checkedConvert) {
    final val = _UpdateTaskArguments(
      taskId: $checkedConvert('task_id', (v) => v as String),
      name: $checkedConvert('name', (v) => v as String?),
      prompt: $checkedConvert('prompt', (v) => v as String?),
      commandArguments: $checkedConvert(
        'command_arguments',
        (v) => v as String?,
      ),
      schedule: $checkedConvert(
        'schedule',
        (v) => v == null
            ? null
            : TaskSchedule.fromJson(Map<String, dynamic>.from(v as Map)),
      ),
      timeZone: $checkedConvert('time_zone', (v) => v as String?),
      missedRunPolicy: $checkedConvert(
        'missed_run_policy',
        (v) => $enumDecodeNullable(_$TaskMissedRunPolicyEnumMap, v),
      ),
      runMode: $checkedConvert(
        'run_mode',
        (v) => v == null
            ? null
            : TaskRunMode.fromJson(Map<String, dynamic>.from(v as Map)),
      ),
      model: $checkedConvert('model', (v) => v as String?),
      effort: $checkedConvert('effort', (v) => v as String?),
      approvalMode: $checkedConvert(
        'approval_mode',
        (v) => $enumDecodeNullable(_$TaskApprovalModeEnumMap, v),
      ),
    );
    return val;
  },
  fieldKeyMap: const {
    'taskId': 'task_id',
    'commandArguments': 'command_arguments',
    'timeZone': 'time_zone',
    'missedRunPolicy': 'missed_run_policy',
    'runMode': 'run_mode',
    'approvalMode': 'approval_mode',
  },
);

Map<String, dynamic> _$UpdateTaskArgumentsToJson(
  _UpdateTaskArguments instance,
) => <String, dynamic>{
  'task_id': instance.taskId,
  'name': ?instance.name,
  'prompt': ?instance.prompt,
  'command_arguments': ?instance.commandArguments,
  'schedule': ?instance.schedule?.toJson(),
  'time_zone': ?instance.timeZone,
  'missed_run_policy': ?_$TaskMissedRunPolicyEnumMap[instance.missedRunPolicy],
  'run_mode': ?instance.runMode?.toJson(),
  'model': ?instance.model,
  'effort': ?instance.effort,
  'approval_mode': ?_$TaskApprovalModeEnumMap[instance.approvalMode],
};
