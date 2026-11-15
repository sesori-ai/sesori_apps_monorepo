// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'scheduled_task.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ScheduledTask _$ScheduledTaskFromJson(Map json) => _ScheduledTask(
  id: json['id'] as String,
  definition: ScheduledTaskDefinition.fromJson(
    Map<String, dynamic>.from(json['definition'] as Map),
  ),
  enabled: json['enabled'] as bool,
  nextRunAt: json['nextRunAt'] == null
      ? null
      : ScheduledTaskInstant.fromJson(
          Map<String, dynamic>.from(json['nextRunAt'] as Map),
        ),
  lastRun: json['lastRun'] == null
      ? null
      : ScheduledTaskRun.fromJson(
          Map<String, dynamic>.from(json['lastRun'] as Map),
        ),
);

Map<String, dynamic> _$ScheduledTaskToJson(_ScheduledTask instance) =>
    <String, dynamic>{
      'id': instance.id,
      'definition': instance.definition.toJson(),
      'enabled': instance.enabled,
      'nextRunAt': ?instance.nextRunAt?.toJson(),
      'lastRun': ?instance.lastRun?.toJson(),
    };

_ScheduledTaskDefinition _$ScheduledTaskDefinitionFromJson(Map json) =>
    _ScheduledTaskDefinition(
      name: json['name'] as String,
      prompt: ScheduledTaskPrompt.fromJson(
        Map<String, dynamic>.from(json['prompt'] as Map),
      ),
      projectId: json['projectId'] as String,
      pluginId: json['pluginId'] as String,
      agent: json['agent'] as String?,
      model: json['model'] == null
          ? null
          : PromptModel.fromJson(
              Map<String, dynamic>.from(json['model'] as Map),
            ),
      variant: json['variant'] == null
          ? null
          : SessionVariant.fromJson(
              Map<String, dynamic>.from(json['variant'] as Map),
            ),
      fastMode: json['fastMode'] as bool,
      dedicatedWorktree: json['dedicatedWorktree'] as bool,
      schedule: TaskSchedule.fromJson(
        Map<String, dynamic>.from(json['schedule'] as Map),
      ),
      timeZone: json['timeZone'] as String,
      missedRunPolicy: $enumDecode(
        _$TaskMissedRunPolicyEnumMap,
        json['missedRunPolicy'],
        unknownValue: TaskMissedRunPolicy.unknown,
      ),
      runMode: TaskRunMode.fromJson(
        Map<String, dynamic>.from(json['runMode'] as Map),
      ),
      approvalMode: $enumDecode(
        _$TaskApprovalModeEnumMap,
        json['approvalMode'],
        unknownValue: TaskApprovalMode.unknown,
      ),
    );

Map<String, dynamic> _$ScheduledTaskDefinitionToJson(
  _ScheduledTaskDefinition instance,
) => <String, dynamic>{
  'name': instance.name,
  'prompt': instance.prompt.toJson(),
  'projectId': instance.projectId,
  'pluginId': instance.pluginId,
  'agent': ?instance.agent,
  'model': ?instance.model?.toJson(),
  'variant': ?instance.variant?.toJson(),
  'fastMode': instance.fastMode,
  'dedicatedWorktree': instance.dedicatedWorktree,
  'schedule': instance.schedule.toJson(),
  'timeZone': instance.timeZone,
  'missedRunPolicy': _$TaskMissedRunPolicyEnumMap[instance.missedRunPolicy]!,
  'runMode': instance.runMode.toJson(),
  'approvalMode': _$TaskApprovalModeEnumMap[instance.approvalMode]!,
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

ScheduledTaskPromptText _$ScheduledTaskPromptTextFromJson(Map json) =>
    ScheduledTaskPromptText(
      text: json['text'] as String,
      $type: json['kind'] as String?,
    );

Map<String, dynamic> _$ScheduledTaskPromptTextToJson(
  ScheduledTaskPromptText instance,
) => <String, dynamic>{'text': instance.text, 'kind': instance.$type};

ScheduledTaskPromptCommand _$ScheduledTaskPromptCommandFromJson(Map json) =>
    ScheduledTaskPromptCommand(
      name: json['name'] as String,
      source: $enumDecode(
        _$CommandSourceEnumMap,
        json['source'],
        unknownValue: CommandSource.unknown,
      ),
      arguments: json['arguments'] as String?,
      $type: json['kind'] as String?,
    );

Map<String, dynamic> _$ScheduledTaskPromptCommandToJson(
  ScheduledTaskPromptCommand instance,
) => <String, dynamic>{
  'name': instance.name,
  'source': _$CommandSourceEnumMap[instance.source]!,
  'arguments': ?instance.arguments,
  'kind': instance.$type,
};

const _$CommandSourceEnumMap = {
  CommandSource.command: 'command',
  CommandSource.mcp: 'mcp',
  CommandSource.skill: 'skill',
  CommandSource.unknown: 'unknown',
};

ScheduledTaskPromptUnknown _$ScheduledTaskPromptUnknownFromJson(Map json) =>
    ScheduledTaskPromptUnknown($type: json['kind'] as String?);

Map<String, dynamic> _$ScheduledTaskPromptUnknownToJson(
  ScheduledTaskPromptUnknown instance,
) => <String, dynamic>{'kind': instance.$type};

TaskScheduleOnce _$TaskScheduleOnceFromJson(Map json) => TaskScheduleOnce(
  at: TaskLocalDateTime.fromJson(Map<String, dynamic>.from(json['at'] as Map)),
  $type: json['kind'] as String?,
);

Map<String, dynamic> _$TaskScheduleOnceToJson(TaskScheduleOnce instance) =>
    <String, dynamic>{'at': instance.at.toJson(), 'kind': instance.$type};

TaskScheduleDaily _$TaskScheduleDailyFromJson(Map json) => TaskScheduleDaily(
  time: TaskTimeOfDay.fromJson(Map<String, dynamic>.from(json['time'] as Map)),
  $type: json['kind'] as String?,
);

Map<String, dynamic> _$TaskScheduleDailyToJson(TaskScheduleDaily instance) =>
    <String, dynamic>{'time': instance.time.toJson(), 'kind': instance.$type};

TaskScheduleWeekdays _$TaskScheduleWeekdaysFromJson(Map json) =>
    TaskScheduleWeekdays(
      time: TaskTimeOfDay.fromJson(
        Map<String, dynamic>.from(json['time'] as Map),
      ),
      $type: json['kind'] as String?,
    );

Map<String, dynamic> _$TaskScheduleWeekdaysToJson(
  TaskScheduleWeekdays instance,
) => <String, dynamic>{'time': instance.time.toJson(), 'kind': instance.$type};

TaskScheduleWeekly _$TaskScheduleWeeklyFromJson(Map json) => TaskScheduleWeekly(
  days: (json['days'] as List<dynamic>)
      .map((e) => $enumDecode(_$TaskWeekdayEnumMap, e))
      .toSet(),
  time: TaskTimeOfDay.fromJson(Map<String, dynamic>.from(json['time'] as Map)),
  $type: json['kind'] as String?,
);

Map<String, dynamic> _$TaskScheduleWeeklyToJson(TaskScheduleWeekly instance) =>
    <String, dynamic>{
      'days': instance.days.map((e) => _$TaskWeekdayEnumMap[e]!).toList(),
      'time': instance.time.toJson(),
      'kind': instance.$type,
    };

const _$TaskWeekdayEnumMap = {
  TaskWeekday.monday: 'monday',
  TaskWeekday.tuesday: 'tuesday',
  TaskWeekday.wednesday: 'wednesday',
  TaskWeekday.thursday: 'thursday',
  TaskWeekday.friday: 'friday',
  TaskWeekday.saturday: 'saturday',
  TaskWeekday.sunday: 'sunday',
};

TaskScheduleEveryHours _$TaskScheduleEveryHoursFromJson(Map json) =>
    TaskScheduleEveryHours(
      hours: (json['hours'] as num).toInt(),
      start: TaskLocalDateTime.fromJson(
        Map<String, dynamic>.from(json['start'] as Map),
      ),
      $type: json['kind'] as String?,
    );

Map<String, dynamic> _$TaskScheduleEveryHoursToJson(
  TaskScheduleEveryHours instance,
) => <String, dynamic>{
  'hours': instance.hours,
  'start': instance.start.toJson(),
  'kind': instance.$type,
};

TaskScheduleUnknown _$TaskScheduleUnknownFromJson(Map json) =>
    TaskScheduleUnknown($type: json['kind'] as String?);

Map<String, dynamic> _$TaskScheduleUnknownToJson(
  TaskScheduleUnknown instance,
) => <String, dynamic>{'kind': instance.$type};

_TaskTimeOfDay _$TaskTimeOfDayFromJson(Map json) => _TaskTimeOfDay(
  hour: (json['hour'] as num).toInt(),
  minute: (json['minute'] as num).toInt(),
);

Map<String, dynamic> _$TaskTimeOfDayToJson(_TaskTimeOfDay instance) =>
    <String, dynamic>{'hour': instance.hour, 'minute': instance.minute};

_TaskLocalDateTime _$TaskLocalDateTimeFromJson(Map json) => _TaskLocalDateTime(
  year: (json['year'] as num).toInt(),
  month: (json['month'] as num).toInt(),
  day: (json['day'] as num).toInt(),
  hour: (json['hour'] as num).toInt(),
  minute: (json['minute'] as num).toInt(),
);

Map<String, dynamic> _$TaskLocalDateTimeToJson(_TaskLocalDateTime instance) =>
    <String, dynamic>{
      'year': instance.year,
      'month': instance.month,
      'day': instance.day,
      'hour': instance.hour,
      'minute': instance.minute,
    };

TaskRunModeNewSession _$TaskRunModeNewSessionFromJson(Map json) =>
    TaskRunModeNewSession($type: json['kind'] as String?);

Map<String, dynamic> _$TaskRunModeNewSessionToJson(
  TaskRunModeNewSession instance,
) => <String, dynamic>{'kind': instance.$type};

TaskRunModeSameSession _$TaskRunModeSameSessionFromJson(Map json) =>
    TaskRunModeSameSession(
      autoCompact: json['autoCompact'] as bool,
      $type: json['kind'] as String?,
    );

Map<String, dynamic> _$TaskRunModeSameSessionToJson(
  TaskRunModeSameSession instance,
) => <String, dynamic>{
  'autoCompact': instance.autoCompact,
  'kind': instance.$type,
};

TaskRunModeUnknown _$TaskRunModeUnknownFromJson(Map json) =>
    TaskRunModeUnknown($type: json['kind'] as String?);

Map<String, dynamic> _$TaskRunModeUnknownToJson(TaskRunModeUnknown instance) =>
    <String, dynamic>{'kind': instance.$type};

_ScheduledTaskInstant _$ScheduledTaskInstantFromJson(Map json) =>
    _ScheduledTaskInstant(
      at: (json['at'] as num).toInt(),
      offsetMinutes: (json['offsetMinutes'] as num).toInt(),
    );

Map<String, dynamic> _$ScheduledTaskInstantToJson(
  _ScheduledTaskInstant instance,
) => <String, dynamic>{
  'at': instance.at,
  'offsetMinutes': instance.offsetMinutes,
};

_ScheduledTaskRun _$ScheduledTaskRunFromJson(Map json) => _ScheduledTaskRun(
  id: json['id'] as String,
  scheduledFor: ScheduledTaskInstant.fromJson(
    Map<String, dynamic>.from(json['scheduledFor'] as Map),
  ),
  outcome: ScheduledTaskRunOutcome.fromJson(
    Map<String, dynamic>.from(json['outcome'] as Map),
  ),
);

Map<String, dynamic> _$ScheduledTaskRunToJson(_ScheduledTaskRun instance) =>
    <String, dynamic>{
      'id': instance.id,
      'scheduledFor': instance.scheduledFor.toJson(),
      'outcome': instance.outcome.toJson(),
    };

ScheduledTaskRunStarted _$ScheduledTaskRunStartedFromJson(Map json) =>
    ScheduledTaskRunStarted(
      sessionId: json['sessionId'] as String?,
      late: json['late'] as bool,
      $type: json['kind'] as String?,
    );

Map<String, dynamic> _$ScheduledTaskRunStartedToJson(
  ScheduledTaskRunStarted instance,
) => <String, dynamic>{
  'sessionId': ?instance.sessionId,
  'late': instance.late,
  'kind': instance.$type,
};

ScheduledTaskRunSkipped _$ScheduledTaskRunSkippedFromJson(Map json) =>
    ScheduledTaskRunSkipped($type: json['kind'] as String?);

Map<String, dynamic> _$ScheduledTaskRunSkippedToJson(
  ScheduledTaskRunSkipped instance,
) => <String, dynamic>{'kind': instance.$type};

ScheduledTaskRunMissed _$ScheduledTaskRunMissedFromJson(Map json) =>
    ScheduledTaskRunMissed($type: json['kind'] as String?);

Map<String, dynamic> _$ScheduledTaskRunMissedToJson(
  ScheduledTaskRunMissed instance,
) => <String, dynamic>{'kind': instance.$type};

ScheduledTaskRunFailed _$ScheduledTaskRunFailedFromJson(Map json) =>
    ScheduledTaskRunFailed(
      reason: $enumDecode(
        _$TaskRunFailureReasonEnumMap,
        json['reason'],
        unknownValue: TaskRunFailureReason.unknown,
      ),
      $type: json['kind'] as String?,
    );

Map<String, dynamic> _$ScheduledTaskRunFailedToJson(
  ScheduledTaskRunFailed instance,
) => <String, dynamic>{
  'reason': _$TaskRunFailureReasonEnumMap[instance.reason]!,
  'kind': instance.$type,
};

const _$TaskRunFailureReasonEnumMap = {
  TaskRunFailureReason.projectMissing: 'projectMissing',
  TaskRunFailureReason.harnessUnavailable: 'harnessUnavailable',
  TaskRunFailureReason.modelUnavailable: 'modelUnavailable',
  TaskRunFailureReason.startFailed: 'startFailed',
  TaskRunFailureReason.unknown: 'unknown',
};

ScheduledTaskRunOutcomeUnknown _$ScheduledTaskRunOutcomeUnknownFromJson(
  Map json,
) => ScheduledTaskRunOutcomeUnknown($type: json['kind'] as String?);

Map<String, dynamic> _$ScheduledTaskRunOutcomeUnknownToJson(
  ScheduledTaskRunOutcomeUnknown instance,
) => <String, dynamic>{'kind': instance.$type};

_SessionScheduledTaskMark _$SessionScheduledTaskMarkFromJson(Map json) =>
    _SessionScheduledTaskMark(
      taskId: json['taskId'] as String,
      name: json['name'] as String,
      kind: $enumDecode(
        _$ScheduledTaskKindEnumMap,
        json['kind'],
        unknownValue: ScheduledTaskKind.unknown,
      ),
    );

Map<String, dynamic> _$SessionScheduledTaskMarkToJson(
  _SessionScheduledTaskMark instance,
) => <String, dynamic>{
  'taskId': instance.taskId,
  'name': instance.name,
  'kind': _$ScheduledTaskKindEnumMap[instance.kind]!,
};

const _$ScheduledTaskKindEnumMap = {
  ScheduledTaskKind.recurring: 'recurring',
  ScheduledTaskKind.once: 'once',
  ScheduledTaskKind.unknown: 'unknown',
};
