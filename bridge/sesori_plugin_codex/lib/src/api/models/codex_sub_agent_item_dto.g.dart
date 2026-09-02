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

Map<String, dynamic> _$CodexSubAgentItemParamsDtoToJson(
  _CodexSubAgentItemParamsDto instance,
) => <String, dynamic>{
  'threadId': ?instance.threadId,
  'turnId': ?instance.turnId,
  'item': instance.item.toJson(),
};

_CodexSubAgentItemDto _$CodexSubAgentItemDtoFromJson(Map json) =>
    _CodexSubAgentItemDto(
      type:
          $enumDecodeNullable(
            _$CodexSubAgentItemTypeEnumMap,
            json['type'],
            unknownValue: CodexSubAgentItemType.unknown,
          ) ??
          CodexSubAgentItemType.unknown,
      id: json['id'] as String?,
      tool: _collabToolFromJson(json['tool']),
      status: _collabItemStatusFromJson(json['status']),
      senderThreadId: _textFromJson(json['senderThreadId']),
      receiverThreadIds: _threadIdListFromJson(json['receiverThreadIds']),
      receiverThreadId: _textFromJson(json['receiverThreadId']),
      newThreadId: _textFromJson(json['newThreadId']),
      prompt: _textFromJson(json['prompt']),
      agentsStates: const CodexCollabAgentStatesConverter().fromJson(
        json['agentsStates'],
      ),
      kind: _activityKindFromJson(json['kind']),
      agentThreadId: _textFromJson(json['agentThreadId']),
      agentPath: _textFromJson(json['agentPath']),
    );

Map<String, dynamic> _$CodexSubAgentItemDtoToJson(
  _CodexSubAgentItemDto instance,
) => <String, dynamic>{
  'type': _$CodexSubAgentItemTypeEnumMap[instance.type]!,
  'id': ?instance.id,
  'tool': _$CodexCollabToolEnumMap[instance.tool]!,
  'status': _$CodexCollabItemStatusEnumMap[instance.status]!,
  'senderThreadId': ?instance.senderThreadId,
  'receiverThreadIds': instance.receiverThreadIds,
  'receiverThreadId': ?instance.receiverThreadId,
  'newThreadId': ?instance.newThreadId,
  'prompt': ?instance.prompt,
  'agentsStates': ?const CodexCollabAgentStatesConverter().toJson(
    instance.agentsStates,
  ),
  'kind': _$CodexSubAgentActivityKindEnumMap[instance.kind]!,
  'agentThreadId': ?instance.agentThreadId,
  'agentPath': ?instance.agentPath,
};

const _$CodexSubAgentItemTypeEnumMap = {
  CodexSubAgentItemType.collabAgentToolCall: 'collabAgentToolCall',
  CodexSubAgentItemType.collabToolCall: 'collabToolCall',
  CodexSubAgentItemType.subAgentActivity: 'subAgentActivity',
  CodexSubAgentItemType.unknown: 'unknown',
};

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

const _$CodexSubAgentActivityKindEnumMap = {
  CodexSubAgentActivityKind.started: 'started',
  CodexSubAgentActivityKind.interacted: 'interacted',
  CodexSubAgentActivityKind.interrupted: 'interrupted',
  CodexSubAgentActivityKind.completed: 'completed',
  CodexSubAgentActivityKind.unknown: 'unknown',
};
