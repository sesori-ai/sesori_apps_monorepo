// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'codex_command_execution_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_CodexCommandExecutionParamsDto _$CodexCommandExecutionParamsDtoFromJson(
  Map json,
) => _CodexCommandExecutionParamsDto(
  threadId: json['threadId'] as String?,
  turnId: json['turnId'] as String?,
  item: CodexCommandExecutionItemDto.fromJson(
    Map<String, dynamic>.from(json['item'] as Map),
  ),
);

Map<String, dynamic> _$CodexCommandExecutionParamsDtoToJson(
  _CodexCommandExecutionParamsDto instance,
) => <String, dynamic>{
  'threadId': instance.threadId,
  'turnId': instance.turnId,
  'item': instance.item.toJson(),
};

_CodexCommandExecutionItemDto _$CodexCommandExecutionItemDtoFromJson(
  Map json,
) => _CodexCommandExecutionItemDto(
  type:
      $enumDecodeNullable(
        _$CodexCommandExecutionItemTypeEnumMap,
        json['type'],
        unknownValue: CodexCommandExecutionItemType.unknown,
      ) ??
      CodexCommandExecutionItemType.unknown,
  id: json['id'] as String?,
  status:
      $enumDecodeNullable(
        _$CodexCommandExecutionStatusEnumMap,
        json['status'],
        unknownValue: CodexCommandExecutionStatus.unknown,
      ) ??
      CodexCommandExecutionStatus.unknown,
  exitCode: (json['exitCode'] as num?)?.toInt(),
);

Map<String, dynamic> _$CodexCommandExecutionItemDtoToJson(
  _CodexCommandExecutionItemDto instance,
) => <String, dynamic>{
  'type': _$CodexCommandExecutionItemTypeEnumMap[instance.type]!,
  'id': instance.id,
  'status': _$CodexCommandExecutionStatusEnumMap[instance.status]!,
  'exitCode': instance.exitCode,
};

const _$CodexCommandExecutionItemTypeEnumMap = {
  CodexCommandExecutionItemType.commandExecution: 'commandExecution',
  CodexCommandExecutionItemType.unknown: 'unknown',
};

const _$CodexCommandExecutionStatusEnumMap = {
  CodexCommandExecutionStatus.inProgress: 'inProgress',
  CodexCommandExecutionStatus.completed: 'completed',
  CodexCommandExecutionStatus.failed: 'failed',
  CodexCommandExecutionStatus.declined: 'declined',
  CodexCommandExecutionStatus.unknown: 'unknown',
};
