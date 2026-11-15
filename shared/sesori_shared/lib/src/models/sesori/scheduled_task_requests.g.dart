// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'scheduled_task_requests.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ScheduledTaskListResponse _$ScheduledTaskListResponseFromJson(Map json) =>
    _ScheduledTaskListResponse(
      items: (json['items'] as List<dynamic>)
          .map(
            (e) => ScheduledTask.fromJson(Map<String, dynamic>.from(e as Map)),
          )
          .toList(),
    );

Map<String, dynamic> _$ScheduledTaskListResponseToJson(
  _ScheduledTaskListResponse instance,
) => <String, dynamic>{'items': instance.items.map((e) => e.toJson()).toList()};

_CreateScheduledTaskRequest _$CreateScheduledTaskRequestFromJson(Map json) =>
    _CreateScheduledTaskRequest(
      definition: ScheduledTaskDefinition.fromJson(
        Map<String, dynamic>.from(json['definition'] as Map),
      ),
    );

Map<String, dynamic> _$CreateScheduledTaskRequestToJson(
  _CreateScheduledTaskRequest instance,
) => <String, dynamic>{'definition': instance.definition.toJson()};

_UpdateScheduledTaskRequest _$UpdateScheduledTaskRequestFromJson(Map json) =>
    _UpdateScheduledTaskRequest(
      taskId: json['taskId'] as String,
      definition: ScheduledTaskDefinition.fromJson(
        Map<String, dynamic>.from(json['definition'] as Map),
      ),
    );

Map<String, dynamic> _$UpdateScheduledTaskRequestToJson(
  _UpdateScheduledTaskRequest instance,
) => <String, dynamic>{
  'taskId': instance.taskId,
  'definition': instance.definition.toJson(),
};

_SetScheduledTaskEnabledRequest _$SetScheduledTaskEnabledRequestFromJson(
  Map json,
) => _SetScheduledTaskEnabledRequest(
  taskId: json['taskId'] as String,
  enabled: json['enabled'] as bool,
);

Map<String, dynamic> _$SetScheduledTaskEnabledRequestToJson(
  _SetScheduledTaskEnabledRequest instance,
) => <String, dynamic>{'taskId': instance.taskId, 'enabled': instance.enabled};

_ScheduledTaskIdRequest _$ScheduledTaskIdRequestFromJson(Map json) =>
    _ScheduledTaskIdRequest(taskId: json['taskId'] as String);

Map<String, dynamic> _$ScheduledTaskIdRequestToJson(
  _ScheduledTaskIdRequest instance,
) => <String, dynamic>{'taskId': instance.taskId};

_ScheduledTaskResponse _$ScheduledTaskResponseFromJson(Map json) =>
    _ScheduledTaskResponse(
      task: ScheduledTask.fromJson(
        Map<String, dynamic>.from(json['task'] as Map),
      ),
    );

Map<String, dynamic> _$ScheduledTaskResponseToJson(
  _ScheduledTaskResponse instance,
) => <String, dynamic>{'task': instance.task.toJson()};

_ScheduledTaskRunListResponse _$ScheduledTaskRunListResponseFromJson(
  Map json,
) => _ScheduledTaskRunListResponse(
  items: (json['items'] as List<dynamic>)
      .map(
        (e) => ScheduledTaskRun.fromJson(Map<String, dynamic>.from(e as Map)),
      )
      .toList(),
);

Map<String, dynamic> _$ScheduledTaskRunListResponseToJson(
  _ScheduledTaskRunListResponse instance,
) => <String, dynamic>{'items': instance.items.map((e) => e.toJson()).toList()};

_ScheduledTaskRunResponse _$ScheduledTaskRunResponseFromJson(Map json) =>
    _ScheduledTaskRunResponse(
      run: ScheduledTaskRun.fromJson(
        Map<String, dynamic>.from(json['run'] as Map),
      ),
    );

Map<String, dynamic> _$ScheduledTaskRunResponseToJson(
  _ScheduledTaskRunResponse instance,
) => <String, dynamic>{'run': instance.run.toJson()};

_ScheduledTaskErrorResponse _$ScheduledTaskErrorResponseFromJson(Map json) =>
    _ScheduledTaskErrorResponse(
      code: $enumDecode(
        _$ScheduledTaskErrorCodeEnumMap,
        json['code'],
        unknownValue: ScheduledTaskErrorCode.unknown,
      ),
    );

Map<String, dynamic> _$ScheduledTaskErrorResponseToJson(
  _ScheduledTaskErrorResponse instance,
) => <String, dynamic>{'code': _$ScheduledTaskErrorCodeEnumMap[instance.code]!};

const _$ScheduledTaskErrorCodeEnumMap = {
  ScheduledTaskErrorCode.taskNotFound: 'taskNotFound',
  ScheduledTaskErrorCode.emptyName: 'emptyName',
  ScheduledTaskErrorCode.emptyPrompt: 'emptyPrompt',
  ScheduledTaskErrorCode.unknownProject: 'unknownProject',
  ScheduledTaskErrorCode.unknownHarness: 'unknownHarness',
  ScheduledTaskErrorCode.unknownTimeZone: 'unknownTimeZone',
  ScheduledTaskErrorCode.invalidSchedule: 'invalidSchedule',
  ScheduledTaskErrorCode.hoursOutOfRange: 'hoursOutOfRange',
  ScheduledTaskErrorCode.onceTimeInPast: 'onceTimeInPast',
  ScheduledTaskErrorCode.unsupportedByBridge: 'unsupportedByBridge',
  ScheduledTaskErrorCode.previousRunActive: 'previousRunActive',
  ScheduledTaskErrorCode.unknown: 'unknown',
};
