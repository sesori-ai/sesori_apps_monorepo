// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'grok_session_notification_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_GrokSessionNotificationDto _$GrokSessionNotificationDtoFromJson(Map json) =>
    _GrokSessionNotificationDto(
      sessionId: json['sessionId'] as String,
      update: GrokSubagentUpdate.fromJson(
        Map<String, dynamic>.from(json['update'] as Map),
      ),
    );

GrokSubagentSpawned _$GrokSubagentSpawnedFromJson(Map json) =>
    GrokSubagentSpawned(
      subagentId: json['subagent_id'] as String,
      childSessionId: json['child_session_id'] as String,
      subagentType: json['subagent_type'] as String?,
      description: json['description'] as String?,
      $type: json['sessionUpdate'] as String?,
    );

GrokSubagentProgress _$GrokSubagentProgressFromJson(Map json) =>
    GrokSubagentProgress(
      subagentId: json['subagent_id'] as String,
      $type: json['sessionUpdate'] as String?,
    );

GrokSubagentFinished _$GrokSubagentFinishedFromJson(Map json) =>
    GrokSubagentFinished(
      subagentId: json['subagent_id'] as String,
      childSessionId: json['child_session_id'] as String,
      status: $enumDecode(
        _$GrokSubagentStatusEnumMap,
        json['status'],
        unknownValue: GrokSubagentStatus.unknown,
      ),
      output: json['output'] as String?,
      error: json['error'] as String?,
      $type: json['sessionUpdate'] as String?,
    );

const _$GrokSubagentStatusEnumMap = {
  GrokSubagentStatus.completed: 'completed',
  GrokSubagentStatus.failed: 'failed',
  GrokSubagentStatus.cancelled: 'cancelled',
  GrokSubagentStatus.unknown: 'unknown',
};

GrokSubagentUpdateUnknown _$GrokSubagentUpdateUnknownFromJson(Map json) =>
    GrokSubagentUpdateUnknown($type: json['sessionUpdate'] as String?);

_GrokToolCallMetaDto _$GrokToolCallMetaDtoFromJson(Map json) =>
    _GrokToolCallMetaDto(
      tool: json['x.ai/tool'] == null
          ? null
          : GrokToolIdentityDto.fromJson(
              Map<String, dynamic>.from(json['x.ai/tool'] as Map),
            ),
    );

_GrokToolIdentityDto _$GrokToolIdentityDtoFromJson(Map json) =>
    _GrokToolIdentityDto(
      name: json['name'] as String?,
      kind: json['kind'] as String?,
    );
