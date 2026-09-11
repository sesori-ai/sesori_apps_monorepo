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
