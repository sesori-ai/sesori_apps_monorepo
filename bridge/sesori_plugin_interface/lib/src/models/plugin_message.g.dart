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

Map<String, dynamic> _$PluginMessagePartTextToJson(
  PluginMessagePartText instance,
) => <String, dynamic>{
  'id': instance.id,
  'sessionID': instance.sessionID,
  'messageID': instance.messageID,
  'text': instance.text,
  'type': instance.$type,
};

Map<String, dynamic> _$PluginMessagePartReasoningToJson(
  PluginMessagePartReasoning instance,
) => <String, dynamic>{
  'id': instance.id,
  'sessionID': instance.sessionID,
  'messageID': instance.messageID,
  'text': instance.text,
  'type': instance.$type,
};

Map<String, dynamic> _$PluginMessagePartToolToJson(
  PluginMessagePartTool instance,
) => <String, dynamic>{
  'id': instance.id,
  'sessionID': instance.sessionID,
  'messageID': instance.messageID,
  'tool': ?instance.tool,
  'state': instance.state.toJson(),
  'type': instance.$type,
};

Map<String, dynamic> _$PluginMessagePartSubtaskToJson(
  PluginMessagePartSubtask instance,
) => <String, dynamic>{
  'id': instance.id,
  'sessionID': instance.sessionID,
  'messageID': instance.messageID,
  'prompt': instance.prompt,
  'description': instance.description,
  'agent': instance.agent,
  'type': instance.$type,
};

Map<String, dynamic> _$PluginMessagePartStepStartToJson(
  PluginMessagePartStepStart instance,
) => <String, dynamic>{
  'id': instance.id,
  'sessionID': instance.sessionID,
  'messageID': instance.messageID,
  'type': instance.$type,
};

Map<String, dynamic> _$PluginMessagePartStepFinishToJson(
  PluginMessagePartStepFinish instance,
) => <String, dynamic>{
  'id': instance.id,
  'sessionID': instance.sessionID,
  'messageID': instance.messageID,
  'type': instance.$type,
};

Map<String, dynamic> _$PluginMessagePartFileToJson(
  PluginMessagePartFile instance,
) => <String, dynamic>{
  'id': instance.id,
  'sessionID': instance.sessionID,
  'messageID': instance.messageID,
  'attachment': instance.attachment.toJson(),
  'type': instance.$type,
};

Map<String, dynamic> _$PluginMessagePartSnapshotToJson(
  PluginMessagePartSnapshot instance,
) => <String, dynamic>{
  'id': instance.id,
  'sessionID': instance.sessionID,
  'messageID': instance.messageID,
  'type': instance.$type,
};

Map<String, dynamic> _$PluginMessagePartPatchToJson(
  PluginMessagePartPatch instance,
) => <String, dynamic>{
  'id': instance.id,
  'sessionID': instance.sessionID,
  'messageID': instance.messageID,
  'type': instance.$type,
};

Map<String, dynamic> _$PluginMessagePartAgentToJson(
  PluginMessagePartAgent instance,
) => <String, dynamic>{
  'id': instance.id,
  'sessionID': instance.sessionID,
  'messageID': instance.messageID,
  'agentName': instance.agentName,
  'type': instance.$type,
};

Map<String, dynamic> _$PluginMessagePartRetryToJson(
  PluginMessagePartRetry instance,
) => <String, dynamic>{
  'id': instance.id,
  'sessionID': instance.sessionID,
  'messageID': instance.messageID,
  'attempt': instance.attempt,
  'retryError': instance.retryError,
  'type': instance.$type,
};

Map<String, dynamic> _$PluginMessagePartCompactionToJson(
  PluginMessagePartCompaction instance,
) => <String, dynamic>{
  'id': instance.id,
  'sessionID': instance.sessionID,
  'messageID': instance.messageID,
  'type': instance.$type,
};

Map<String, dynamic> _$PluginMessagePartUnknownToJson(
  PluginMessagePartUnknown instance,
) => <String, dynamic>{
  'id': instance.id,
  'sessionID': instance.sessionID,
  'messageID': instance.messageID,
  'type': instance.$type,
};

Map<String, dynamic> _$PluginMessageAttachmentInlineImageToJson(
  PluginMessageAttachmentInlineImage instance,
) => <String, dynamic>{
  'mime': instance.mime,
  'base64': instance.base64,
  'filename': ?instance.filename,
  'source': instance.$type,
};

Map<String, dynamic> _$PluginMessageAttachmentRemoteUrlToJson(
  PluginMessageAttachmentRemoteUrl instance,
) => <String, dynamic>{
  'mime': instance.mime,
  'url': instance.url.toString(),
  'filename': ?instance.filename,
  'source': instance.$type,
};

Map<String, dynamic> _$PluginMessageAttachmentMetadataToJson(
  PluginMessageAttachmentMetadata instance,
) => <String, dynamic>{
  'mime': instance.mime,
  'filename': ?instance.filename,
  'source': instance.$type,
};

Map<String, dynamic> _$PluginToolStateToJson(_PluginToolState instance) =>
    <String, dynamic>{
      'status': _$PluginToolStatusEnumMap[instance.status]!,
      'title': ?instance.title,
      'output': ?instance.output,
      'error': ?instance.error,
      'attachments': instance.attachments.map((e) => e.toJson()).toList(),
    };

const _$PluginToolStatusEnumMap = {
  PluginToolStatus.pending: 'pending',
  PluginToolStatus.running: 'running',
  PluginToolStatus.completed: 'completed',
  PluginToolStatus.error: 'error',
  PluginToolStatus.unknown: 'unknown',
};

Map<String, dynamic> _$PluginMessageUserToJson(PluginMessageUser instance) =>
    <String, dynamic>{
      'id': instance.id,
      'sessionID': instance.sessionID,
      'agent': ?instance.agent,
      'time': ?instance.time?.toJson(),
      'promptId': ?instance.promptId,
      'role': instance.$type,
    };

Map<String, dynamic> _$PluginMessageAssistantToJson(
  PluginMessageAssistant instance,
) => <String, dynamic>{
  'id': instance.id,
  'sessionID': instance.sessionID,
  'agent': ?instance.agent,
  'modelID': ?instance.modelID,
  'providerID': ?instance.providerID,
  'variant': ?instance.variant,
  'time': ?instance.time?.toJson(),
  'role': instance.$type,
};

Map<String, dynamic> _$PluginMessageErrorToJson(PluginMessageError instance) =>
    <String, dynamic>{
      'id': instance.id,
      'sessionID': instance.sessionID,
      'agent': ?instance.agent,
      'modelID': ?instance.modelID,
      'providerID': ?instance.providerID,
      'variant': ?instance.variant,
      'errorName': instance.errorName,
      'errorMessage': instance.errorMessage,
      'time': ?instance.time?.toJson(),
      'role': instance.$type,
    };

Map<String, dynamic> _$PluginMessageTimeToJson(_PluginMessageTime instance) =>
    <String, dynamic>{
      'created': instance.created,
      'completed': ?instance.completed,
    };
