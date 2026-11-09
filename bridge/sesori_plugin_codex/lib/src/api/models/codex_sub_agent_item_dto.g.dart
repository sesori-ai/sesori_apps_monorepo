// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'codex_sub_agent_item_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_CodexSubAgentItemParamsDto _$CodexSubAgentItemParamsDtoFromJson(Map json) => _CodexSubAgentItemParamsDto(
  threadId: json['threadId'] as String?,
  turnId: json['turnId'] as String?,
  item: CodexSubAgentItemDto.fromJson(
    Map<String, dynamic>.from(json['item'] as Map),
  ),
);

CodexSubAgentActivityItemDto _$CodexSubAgentActivityItemDtoFromJson(Map json) => CodexSubAgentActivityItemDto(
  id: json['id'] as String?,
  kind:
      $enumDecodeNullable(
        _$CodexSubAgentActivityKindEnumMap,
        json['kind'],
        unknownValue: CodexSubAgentActivityKind.unknown,
      ) ??
      CodexSubAgentActivityKind.unknown,
  agentThreadId: _textFromJson(json['agentThreadId']),
  agentPath: _textFromJson(json['agentPath']),
  $type: json['type'] as String?,
);

const _$CodexSubAgentActivityKindEnumMap = {
  CodexSubAgentActivityKind.started: 'started',
  CodexSubAgentActivityKind.interacted: 'interacted',
  CodexSubAgentActivityKind.interrupted: 'interrupted',
  CodexSubAgentActivityKind.completed: 'completed',
  CodexSubAgentActivityKind.unknown: 'unknown',
};

CodexUnknownSubAgentItemDto _$CodexUnknownSubAgentItemDtoFromJson(Map json) =>
    CodexUnknownSubAgentItemDto($type: json['type'] as String?);
