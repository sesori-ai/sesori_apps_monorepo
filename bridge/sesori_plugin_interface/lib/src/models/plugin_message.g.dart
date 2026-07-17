// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'plugin_message.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Map<String, dynamic> _$PluginMessageWithPartsToJson(
  _PluginMessageWithParts instance,
) => <String, dynamic>{
  'info': instance.info.toJson(),
  'parts': instance.parts.map((e) => e.toJson()).toList(),
};

Map<String, dynamic> _$PluginMessagePartToJson(_PluginMessagePart instance) =>
    <String, dynamic>{
      'id': instance.id,
      'sessionID': instance.sessionID,
      'messageID': instance.messageID,
      'type': _$PluginMessagePartTypeEnumMap[instance.type]!,
      'text': ?instance.text,
      'tool': ?instance.tool,
      'state': ?instance.state?.toJson(),
      'prompt': ?instance.prompt,
      'description': ?instance.description,
      'agent': ?instance.agent,
      'agentName': ?instance.agentName,
      'attempt': ?instance.attempt,
      'retryError': ?instance.retryError,
    };

const _$PluginMessagePartTypeEnumMap = {
  PluginMessagePartType.text: 'text',
  PluginMessagePartType.reasoning: 'reasoning',
  PluginMessagePartType.tool: 'tool',
  PluginMessagePartType.subtask: 'subtask',
  PluginMessagePartType.stepStart: 'step-start',
  PluginMessagePartType.stepFinish: 'step-finish',
  PluginMessagePartType.file: 'file',
  PluginMessagePartType.snapshot: 'snapshot',
  PluginMessagePartType.patch: 'patch',
  PluginMessagePartType.agent: 'agent',
  PluginMessagePartType.retry: 'retry',
  PluginMessagePartType.compaction: 'compaction',
  PluginMessagePartType.unknown: 'unknown',
};

Map<String, dynamic> _$PluginToolStateToJson(_PluginToolState instance) =>
    <String, dynamic>{
      'status': _$PluginToolStatusEnumMap[instance.status]!,
      'title': ?instance.title,
      'output': ?instance.output,
      'error': ?instance.error,
    };

const _$PluginToolStatusEnumMap = {
  PluginToolStatus.pending: 'pending',
  PluginToolStatus.running: 'running',
  PluginToolStatus.completed: 'completed',
  PluginToolStatus.error: 'error',
  PluginToolStatus.unknown: 'unknown',
};

PluginMessageUser _$PluginMessageUserFromJson(Map json) => PluginMessageUser(
  id: json['id'] as String,
  sessionID: json['sessionID'] as String,
  agent: json['agent'] as String?,
  time: json['time'] == null
      ? null
      : PluginMessageTime.fromJson(
          Map<String, dynamic>.from(json['time'] as Map),
        ),
  $type: json['role'] as String?,
);

Map<String, dynamic> _$PluginMessageUserToJson(PluginMessageUser instance) =>
    <String, dynamic>{
      'id': instance.id,
      'sessionID': instance.sessionID,
      'agent': ?instance.agent,
      'time': ?instance.time?.toJson(),
      'role': instance.$type,
    };

PluginMessageCommand _$PluginMessageCommandFromJson(Map json) =>
    PluginMessageCommand(
      id: json['id'] as String,
      sessionID: json['sessionID'] as String,
      name: json['name'] as String,
      arguments: json['arguments'] as String?,
      origin: $enumDecode(
        _$PluginCommandOriginEnumMap,
        json['origin'],
        unknownValue: PluginCommandOrigin.unknown,
      ),
      invocationId: json['invocationId'] as String?,
      time: json['time'] == null
          ? null
          : PluginMessageTime.fromJson(
              Map<String, dynamic>.from(json['time'] as Map),
            ),
      $type: json['role'] as String?,
    );

Map<String, dynamic> _$PluginMessageCommandToJson(
  PluginMessageCommand instance,
) => <String, dynamic>{
  'id': instance.id,
  'sessionID': instance.sessionID,
  'name': instance.name,
  'arguments': ?instance.arguments,
  'origin': _$PluginCommandOriginEnumMap[instance.origin]!,
  'invocationId': ?instance.invocationId,
  'time': ?instance.time?.toJson(),
  'role': instance.$type,
};

const _$PluginCommandOriginEnumMap = {
  PluginCommandOrigin.manual: 'manual',
  PluginCommandOrigin.automatic: 'automatic',
  PluginCommandOrigin.unknown: 'unknown',
};

PluginMessageAssistant _$PluginMessageAssistantFromJson(Map json) =>
    PluginMessageAssistant(
      id: json['id'] as String,
      sessionID: json['sessionID'] as String,
      agent: json['agent'] as String?,
      modelID: json['modelID'] as String?,
      providerID: json['providerID'] as String?,
      time: json['time'] == null
          ? null
          : PluginMessageTime.fromJson(
              Map<String, dynamic>.from(json['time'] as Map),
            ),
      $type: json['role'] as String?,
    );

Map<String, dynamic> _$PluginMessageAssistantToJson(
  PluginMessageAssistant instance,
) => <String, dynamic>{
  'id': instance.id,
  'sessionID': instance.sessionID,
  'agent': ?instance.agent,
  'modelID': ?instance.modelID,
  'providerID': ?instance.providerID,
  'time': ?instance.time?.toJson(),
  'role': instance.$type,
};

PluginMessageError _$PluginMessageErrorFromJson(Map json) => PluginMessageError(
  id: json['id'] as String,
  sessionID: json['sessionID'] as String,
  agent: json['agent'] as String?,
  modelID: json['modelID'] as String?,
  providerID: json['providerID'] as String?,
  errorName: json['errorName'] as String,
  errorMessage: json['errorMessage'] as String,
  time: json['time'] == null
      ? null
      : PluginMessageTime.fromJson(
          Map<String, dynamic>.from(json['time'] as Map),
        ),
  $type: json['role'] as String?,
);

Map<String, dynamic> _$PluginMessageErrorToJson(PluginMessageError instance) =>
    <String, dynamic>{
      'id': instance.id,
      'sessionID': instance.sessionID,
      'agent': ?instance.agent,
      'modelID': ?instance.modelID,
      'providerID': ?instance.providerID,
      'errorName': instance.errorName,
      'errorMessage': instance.errorMessage,
      'time': ?instance.time?.toJson(),
      'role': instance.$type,
    };

_PluginMessageTime _$PluginMessageTimeFromJson(Map json) => _PluginMessageTime(
  created: (json['created'] as num).toInt(),
  completed: (json['completed'] as num?)?.toInt(),
);

Map<String, dynamic> _$PluginMessageTimeToJson(_PluginMessageTime instance) =>
    <String, dynamic>{
      'created': instance.created,
      'completed': ?instance.completed,
    };
