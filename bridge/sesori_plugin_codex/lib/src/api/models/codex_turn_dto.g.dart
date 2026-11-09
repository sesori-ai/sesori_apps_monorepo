// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'codex_turn_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_CodexTurnStartResponseDto _$CodexTurnStartResponseDtoFromJson(Map json) => _CodexTurnStartResponseDto(
  turn: json['turn'] == null
      ? null
      : CodexTurnDto.fromJson(
          Map<String, dynamic>.from(json['turn'] as Map),
        ),
);

_CodexTurnDto _$CodexTurnDtoFromJson(Map json) => _CodexTurnDto(
  id: json['id'] as String?,
  status: $enumDecodeNullable(
    _$CodexTurnStatusEnumMap,
    json['status'],
    unknownValue: CodexTurnStatus.unknown,
  ),
);

const _$CodexTurnStatusEnumMap = {
  CodexTurnStatus.completed: 'completed',
  CodexTurnStatus.interrupted: 'interrupted',
  CodexTurnStatus.failed: 'failed',
  CodexTurnStatus.inProgress: 'inProgress',
  CodexTurnStatus.unknown: 'unknown',
};
