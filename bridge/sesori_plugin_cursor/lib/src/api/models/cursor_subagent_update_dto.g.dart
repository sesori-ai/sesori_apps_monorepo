// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'cursor_subagent_update_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CursorSubagentSpawnedDto _$CursorSubagentSpawnedDtoFromJson(Map json) =>
    CursorSubagentSpawnedDto(
      subagentSessionId: json['subagentSessionId'] as String,
      name: json['name'] as String?,
      task: json['task'] as String?,
      meta: json['_meta'] == null
          ? null
          : CursorSubagentMetaDto.fromJson(
              Map<String, dynamic>.from(json['_meta'] as Map),
            ),
      $type: json['sessionUpdate'] as String?,
    );

CursorSubagentStateUpdateDto _$CursorSubagentStateUpdateDtoFromJson(Map json) =>
    CursorSubagentStateUpdateDto(
      subagentSessionId: json['subagentSessionId'] as String,
      state: $enumDecode(
        _$CursorSubagentStateEnumMap,
        json['state'],
        unknownValue: CursorSubagentState.unknown,
      ),
      $type: json['sessionUpdate'] as String?,
    );

const _$CursorSubagentStateEnumMap = {
  CursorSubagentState.completed: 'completed',
  CursorSubagentState.failed: 'failed',
  CursorSubagentState.cancelled: 'cancelled',
  CursorSubagentState.disconnected: 'disconnected',
  CursorSubagentState.unknown: 'unknown',
};

CursorSubagentUpdateUnknownDto _$CursorSubagentUpdateUnknownDtoFromJson(
  Map json,
) => CursorSubagentUpdateUnknownDto($type: json['sessionUpdate'] as String?);

_CursorSubagentMetaDto _$CursorSubagentMetaDtoFromJson(Map json) =>
    _CursorSubagentMetaDto(
      cursor: json['cursor'] == null
          ? null
          : CursorSubagentCursorMetaDto.fromJson(
              Map<String, dynamic>.from(json['cursor'] as Map),
            ),
    );

_CursorSubagentCursorMetaDto _$CursorSubagentCursorMetaDtoFromJson(Map json) =>
    _CursorSubagentCursorMetaDto(
      toolCallId: json['toolCallId'] as String?,
      model: json['model'] as String?,
    );
