// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'cursor_task_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_CursorTaskInputDto _$CursorTaskInputDtoFromJson(Map json) =>
    _CursorTaskInputDto(
      toolName: $enumDecode(
        _$CursorTaskToolEnumMap,
        json['_toolName'],
        unknownValue: CursorTaskTool.unknown,
      ),
      prompt: json['prompt'] as String?,
      description: json['description'] as String?,
    );

const _$CursorTaskToolEnumMap = {
  CursorTaskTool.task: 'task',
  CursorTaskTool.unknown: 'unknown',
};

_CursorTaskOutputDto _$CursorTaskOutputDtoFromJson(Map json) =>
    _CursorTaskOutputDto(isBackground: json['isBackground'] as bool);

_CursorSubagentUnspecifiedDto _$CursorSubagentUnspecifiedDtoFromJson(
  Map json,
) => _CursorSubagentUnspecifiedDto();

_CursorTaskReplaySubagentTypeDto _$CursorTaskReplaySubagentTypeDtoFromJson(
  Map json,
) => _CursorTaskReplaySubagentTypeDto(
  unspecified: json['unspecified'] == null
      ? null
      : CursorSubagentUnspecifiedDto.fromJson(
          Map<String, dynamic>.from(json['unspecified'] as Map),
        ),
);

_CursorTaskReplayInputDto _$CursorTaskReplayInputDtoFromJson(Map json) =>
    _CursorTaskReplayInputDto(
      toolName: $enumDecode(
        _$CursorTaskToolEnumMap,
        json['_toolName'],
        unknownValue: CursorTaskTool.unknown,
      ),
      prompt: json['prompt'] as String?,
      description: json['description'] as String?,
      subagentType: json['subagentType'] == null
          ? null
          : CursorTaskReplaySubagentTypeDto.fromJson(
              Map<String, dynamic>.from(json['subagentType'] as Map),
            ),
    );

_CursorTaskReplayUpdateDto _$CursorTaskReplayUpdateDtoFromJson(Map json) =>
    _CursorTaskReplayUpdateDto(
      sessionUpdate: $enumDecode(
        _$CursorTaskReplayUpdateKindEnumMap,
        json['sessionUpdate'],
        unknownValue: CursorTaskReplayUpdateKind.unknown,
      ),
      toolCallId: json['toolCallId'] as String?,
      status: $enumDecodeNullable(
        _$CursorTaskReplayStatusEnumMap,
        json['status'],
        unknownValue: CursorTaskReplayStatus.unknown,
      ),
    );

const _$CursorTaskReplayUpdateKindEnumMap = {
  CursorTaskReplayUpdateKind.toolCall: 'tool_call',
  CursorTaskReplayUpdateKind.toolCallUpdate: 'tool_call_update',
  CursorTaskReplayUpdateKind.unknown: 'unknown',
};

const _$CursorTaskReplayStatusEnumMap = {
  CursorTaskReplayStatus.pending: 'pending',
  CursorTaskReplayStatus.inProgress: 'in_progress',
  CursorTaskReplayStatus.completed: 'completed',
  CursorTaskReplayStatus.failed: 'failed',
  CursorTaskReplayStatus.unknown: 'unknown',
};
