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

_SendPageArguments _$SendPageArgumentsFromJson(Map json) =>
    $checkedCreate('_SendPageArguments', json, ($checkedConvert) {
      $checkKeys(json, allowedKeys: const ['title', 'intro', 'sections']);
      final val = _SendPageArguments(
        title: $checkedConvert('title', (v) => v as String),
        intro: $checkedConvert('intro', (v) => v as String?),
        sections: $checkedConvert(
          'sections',
          (v) => (v as List<dynamic>)
              .map(
                (e) => PageSectionArgument.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ),
              )
              .toList(),
        ),
      );
      return val;
    });

_PageSectionArgument _$PageSectionArgumentFromJson(Map json) =>
    $checkedCreate('_PageSectionArgument', json, ($checkedConvert) {
      $checkKeys(
        json,
        allowedKeys: const ['heading', 'body', 'images', 'questions'],
      );
      final val = _PageSectionArgument(
        heading: $checkedConvert('heading', (v) => v as String?),
        body: $checkedConvert('body', (v) => v as String?),
        images: $checkedConvert(
          'images',
          (v) => (v as List<dynamic>?)
              ?.map(
                (e) => PageImageArgument.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ),
              )
              .toList(),
        ),
        questions: $checkedConvert(
          'questions',
          (v) => (v as List<dynamic>?)
              ?.map(
                (e) => PageQuestionArgument.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ),
              )
              .toList(),
        ),
      );
      return val;
    });

_PageImageArgument _$PageImageArgumentFromJson(Map json) =>
    $checkedCreate('_PageImageArgument', json, ($checkedConvert) {
      $checkKeys(json, allowedKeys: const ['path', 'caption']);
      final val = _PageImageArgument(
        path: $checkedConvert('path', (v) => v as String),
        caption: $checkedConvert('caption', (v) => v as String?),
      );
      return val;
    });

_PageQuestionArgument _$PageQuestionArgumentFromJson(Map json) =>
    $checkedCreate('_PageQuestionArgument', json, ($checkedConvert) {
      $checkKeys(
        json,
        allowedKeys: const [
          'id',
          'title',
          'body',
          'images',
          'kind',
          'options',
          'required',
        ],
      );
      final val = _PageQuestionArgument(
        id: $checkedConvert('id', (v) => v as String),
        title: $checkedConvert('title', (v) => v as String),
        body: $checkedConvert('body', (v) => v as String?),
        images: $checkedConvert(
          'images',
          (v) => (v as List<dynamic>?)
              ?.map(
                (e) => PageImageArgument.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ),
              )
              .toList(),
        ),
        kind: $checkedConvert(
          'kind',
          (v) => $enumDecode(_$PageQuestionKindArgumentEnumMap, v),
        ),
        options: $checkedConvert(
          'options',
          (v) => (v as List<dynamic>?)
              ?.map(
                (e) => PageOptionArgument.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ),
              )
              .toList(),
        ),
        required: $checkedConvert('required', (v) => v as bool? ?? false),
      );
      return val;
    });

const _$PageQuestionKindArgumentEnumMap = {
  PageQuestionKindArgument.single: 'single',
  PageQuestionKindArgument.multiple: 'multiple',
  PageQuestionKindArgument.text: 'text',
};

_PageOptionArgument _$PageOptionArgumentFromJson(Map json) => $checkedCreate(
  '_PageOptionArgument',
  json,
  ($checkedConvert) {
    $checkKeys(
      json,
      allowedKeys: const ['id', 'label', 'description', 'image', 'recommended'],
    );
    final val = _PageOptionArgument(
      id: $checkedConvert('id', (v) => v as String),
      label: $checkedConvert('label', (v) => v as String),
      description: $checkedConvert('description', (v) => v as String?),
      image: $checkedConvert(
        'image',
        (v) => v == null
            ? null
            : PageImageArgument.fromJson(Map<String, dynamic>.from(v as Map)),
      ),
      recommended: $checkedConvert('recommended', (v) => v as bool? ?? false),
    );
    return val;
  },
);

_ScheduleWakeUpArguments _$ScheduleWakeUpArgumentsFromJson(Map json) =>
    $checkedCreate('_ScheduleWakeUpArguments', json, ($checkedConvert) {
      final val = _ScheduleWakeUpArguments(
        label: $checkedConvert('label', (v) => v as String),
        prompt: $checkedConvert('prompt', (v) => v as String),
        when: $checkedConvert(
          'when',
          (v) =>
              WakeUpWhenArgument.fromJson(Map<String, dynamic>.from(v as Map)),
        ),
        timeZone: $checkedConvert('time_zone', (v) => v as String?),
      );
      return val;
    }, fieldKeyMap: const {'timeZone': 'time_zone'});

WakeUpWhenAfterArgument _$WakeUpWhenAfterArgumentFromJson(Map json) =>
    WakeUpWhenAfterArgument(
      minutes: (json['minutes'] as num).toInt(),
      $type: json['kind'] as String?,
    );

WakeUpWhenEveryArgument _$WakeUpWhenEveryArgumentFromJson(Map json) =>
    WakeUpWhenEveryArgument(
      minutes: (json['minutes'] as num).toInt(),
      $type: json['kind'] as String?,
    );

WakeUpWhenDailyArgument _$WakeUpWhenDailyArgumentFromJson(Map json) =>
    WakeUpWhenDailyArgument(
      time: json['time'] as String,
      $type: json['kind'] as String?,
    );

WakeUpWhenWeekdaysArgument _$WakeUpWhenWeekdaysArgumentFromJson(Map json) =>
    WakeUpWhenWeekdaysArgument(
      time: json['time'] as String,
      $type: json['kind'] as String?,
    );

WakeUpWhenWeeklyArgument _$WakeUpWhenWeeklyArgumentFromJson(Map json) =>
    WakeUpWhenWeeklyArgument(
      days: (json['days'] as List<dynamic>)
          .map((e) => $enumDecode(_$TaskWeekdayEnumMap, e))
          .toSet(),
      time: json['time'] as String,
      $type: json['kind'] as String?,
    );

const _$TaskWeekdayEnumMap = {
  TaskWeekday.monday: 'monday',
  TaskWeekday.tuesday: 'tuesday',
  TaskWeekday.wednesday: 'wednesday',
  TaskWeekday.thursday: 'thursday',
  TaskWeekday.friday: 'friday',
  TaskWeekday.saturday: 'saturday',
  TaskWeekday.sunday: 'sunday',
};

_CancelWakeUpArguments _$CancelWakeUpArgumentsFromJson(Map json) =>
    $checkedCreate('_CancelWakeUpArguments', json, ($checkedConvert) {
      final val = _CancelWakeUpArguments(
        wakeUpId: $checkedConvert('wakeup_id', (v) => v as String),
      );
      return val;
    }, fieldKeyMap: const {'wakeUpId': 'wakeup_id'});

Map<String, dynamic> _$CancelWakeUpArgumentsToJson(
  _CancelWakeUpArguments instance,
) => <String, dynamic>{'wakeup_id': instance.wakeUpId};
