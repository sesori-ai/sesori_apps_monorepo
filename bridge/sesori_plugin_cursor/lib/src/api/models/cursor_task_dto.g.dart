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
    );

const _$CursorTaskToolEnumMap = {
  CursorTaskTool.task: 'task',
  CursorTaskTool.unknown: 'unknown',
};

_CursorTaskOutputDto _$CursorTaskOutputDtoFromJson(Map json) =>
    _CursorTaskOutputDto(isBackground: json['isBackground'] as bool);

_CursorSubagentTypeDto _$CursorSubagentTypeDtoFromJson(Map json) =>
    _CursorSubagentTypeDto(
      custom: $enumDecodeNullable(
        _$CursorSubagentTypeEnumMap,
        json['custom'],
        unknownValue: CursorSubagentType.unknown,
      ),
    );

const _$CursorSubagentTypeEnumMap = {
  CursorSubagentType.unspecified: 'unspecified',
  CursorSubagentType.unknown: 'unknown',
};

_CursorTaskRequestDto _$CursorTaskRequestDtoFromJson(Map json) =>
    _CursorTaskRequestDto(
      toolCallId: json['toolCallId'] as String,
      description: json['description'] as String,
      prompt: json['prompt'] as String,
      subagentType: CursorSubagentTypeDto.fromJson(
        Map<String, dynamic>.from(json['subagentType'] as Map),
      ),
    );
