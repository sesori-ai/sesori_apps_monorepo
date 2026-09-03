// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'codex_sub_agent_item_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_CodexSubAgentItemParamsDto _$CodexSubAgentItemParamsDtoFromJson(Map json) =>
    _CodexSubAgentItemParamsDto(
      threadId: json['threadId'] as String?,
      turnId: json['turnId'] as String?,
      item: CodexSubAgentItemDto.fromJson(
        Map<String, dynamic>.from(json['item'] as Map),
      ),
    );

_CodexCollabAgentStateDto _$CodexCollabAgentStateDtoFromJson(Map json) =>
    _CodexCollabAgentStateDto(
      status:
          $enumDecodeNullable(
            _$CodexCollabAgentStatusEnumMap,
            json['status'],
            unknownValue: CodexCollabAgentStatus.unknown,
          ) ??
          CodexCollabAgentStatus.unknown,
      message: _textFromJson(json['message']),
    );

const _$CodexCollabAgentStatusEnumMap = {
  CodexCollabAgentStatus.pendingInit: 'pendingInit',
  CodexCollabAgentStatus.running: 'running',
  CodexCollabAgentStatus.completed: 'completed',
  CodexCollabAgentStatus.failed: 'failed',
  CodexCollabAgentStatus.interrupted: 'interrupted',
  CodexCollabAgentStatus.errored: 'errored',
  CodexCollabAgentStatus.shutdown: 'shutdown',
  CodexCollabAgentStatus.notFound: 'notFound',
  CodexCollabAgentStatus.unknown: 'unknown',
};

CodexCollabAgentToolCallItemDto _$CodexCollabAgentToolCallItemDtoFromJson(
  Map json,
) => CodexCollabAgentToolCallItemDto(
  id: json['id'] as String?,
  tool:
      $enumDecodeNullable(
        _$CodexCollabToolEnumMap,
        json['tool'],
        unknownValue: CodexCollabTool.unknown,
      ) ??
      CodexCollabTool.unknown,
  status:
      $enumDecodeNullable(
        _$CodexCollabItemStatusEnumMap,
        json['status'],
        unknownValue: CodexCollabItemStatus.unknown,
      ) ??
      CodexCollabItemStatus.unknown,
  senderThreadId: _textFromJson(json['senderThreadId']),
  receiverThreadIds: _threadIdListFromJson(json['receiverThreadIds']),
  receiverThreadId: _textFromJson(json['receiverThreadId']),
  newThreadId: _textFromJson(json['newThreadId']),
  prompt: _textFromJson(json['prompt']),
  agentsStates:
      (json['agentsStates'] as Map?)?.map(
        (k, e) => MapEntry(
          k as String,
          CodexCollabAgentStateDto.fromJson(
            Map<String, dynamic>.from(e as Map),
          ),
        ),
      ) ??
      {},
  $type: json['type'] as String?,
);

const _$CodexCollabToolEnumMap = {
  CodexCollabTool.spawnAgent: 'spawnAgent',
  CodexCollabTool.sendInput: 'sendInput',
  CodexCollabTool.resumeAgent: 'resumeAgent',
  CodexCollabTool.wait: 'wait',
  CodexCollabTool.closeAgent: 'closeAgent',
  CodexCollabTool.unknown: 'unknown',
};

const _$CodexCollabItemStatusEnumMap = {
  CodexCollabItemStatus.inProgress: 'inProgress',
  CodexCollabItemStatus.completed: 'completed',
  CodexCollabItemStatus.failed: 'failed',
  CodexCollabItemStatus.unknown: 'unknown',
};

CodexSubAgentActivityItemDto _$CodexSubAgentActivityItemDtoFromJson(Map json) =>
    CodexSubAgentActivityItemDto(
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
