// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'message_part.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MessagePartText _$MessagePartTextFromJson(Map json) => MessagePartText(
  id: json['id'] as String,
  sessionID: json['sessionID'] as String,
  messageID: json['messageID'] as String,
  text: json['text'] as String? ?? "",
  $type: json['type'] as String?,
);

Map<String, dynamic> _$MessagePartTextToJson(MessagePartText instance) =>
    <String, dynamic>{
      'id': instance.id,
      'sessionID': instance.sessionID,
      'messageID': instance.messageID,
      'text': instance.text,
      'type': instance.$type,
    };

MessagePartReasoning _$MessagePartReasoningFromJson(Map json) =>
    MessagePartReasoning(
      id: json['id'] as String,
      sessionID: json['sessionID'] as String,
      messageID: json['messageID'] as String,
      text: json['text'] as String? ?? "",
      $type: json['type'] as String?,
    );

Map<String, dynamic> _$MessagePartReasoningToJson(
  MessagePartReasoning instance,
) => <String, dynamic>{
  'id': instance.id,
  'sessionID': instance.sessionID,
  'messageID': instance.messageID,
  'text': instance.text,
  'type': instance.$type,
};

MessagePartTool _$MessagePartToolFromJson(Map json) => MessagePartTool(
  id: json['id'] as String,
  sessionID: json['sessionID'] as String,
  messageID: json['messageID'] as String,
  tool: json['tool'] as String? ?? "",
  state: json['state'] == null
      ? const ToolState(
          status: ToolStatus.pending,
          title: null,
          shellCommand: null,
          output: null,
          error: null,
        )
      : ToolState.fromJson(Map<String, dynamic>.from(json['state'] as Map)),
  $type: json['type'] as String?,
);

Map<String, dynamic> _$MessagePartToolToJson(MessagePartTool instance) =>
    <String, dynamic>{
      'id': instance.id,
      'sessionID': instance.sessionID,
      'messageID': instance.messageID,
      'tool': instance.tool,
      'state': instance.state.toJson(),
      'type': instance.$type,
    };

MessagePartSubtask _$MessagePartSubtaskFromJson(Map json) => MessagePartSubtask(
  id: json['id'] as String,
  sessionID: json['sessionID'] as String,
  messageID: json['messageID'] as String,
  prompt: json['prompt'] as String? ?? "",
  description: json['description'] as String? ?? "",
  agent: json['agent'] as String? ?? "",
  taskState: json['taskState'] == null
      ? null
      : ToolState.fromJson(Map<String, dynamic>.from(json['taskState'] as Map)),
  childSessionID: json['childSessionID'] as String?,
  $type: json['type'] as String?,
);

Map<String, dynamic> _$MessagePartSubtaskToJson(MessagePartSubtask instance) =>
    <String, dynamic>{
      'id': instance.id,
      'sessionID': instance.sessionID,
      'messageID': instance.messageID,
      'prompt': instance.prompt,
      'description': instance.description,
      'agent': instance.agent,
      'taskState': ?instance.taskState?.toJson(),
      'childSessionID': ?instance.childSessionID,
      'type': instance.$type,
    };

MessagePartStepStart _$MessagePartStepStartFromJson(Map json) =>
    MessagePartStepStart(
      id: json['id'] as String,
      sessionID: json['sessionID'] as String,
      messageID: json['messageID'] as String,
      $type: json['type'] as String?,
    );

Map<String, dynamic> _$MessagePartStepStartToJson(
  MessagePartStepStart instance,
) => <String, dynamic>{
  'id': instance.id,
  'sessionID': instance.sessionID,
  'messageID': instance.messageID,
  'type': instance.$type,
};

MessagePartStepFinish _$MessagePartStepFinishFromJson(Map json) =>
    MessagePartStepFinish(
      id: json['id'] as String,
      sessionID: json['sessionID'] as String,
      messageID: json['messageID'] as String,
      $type: json['type'] as String?,
    );

Map<String, dynamic> _$MessagePartStepFinishToJson(
  MessagePartStepFinish instance,
) => <String, dynamic>{
  'id': instance.id,
  'sessionID': instance.sessionID,
  'messageID': instance.messageID,
  'type': instance.$type,
};

MessagePartFile _$MessagePartFileFromJson(Map json) => MessagePartFile(
  id: json['id'] as String,
  sessionID: json['sessionID'] as String,
  messageID: json['messageID'] as String,
  attachment: json['attachment'] == null
      ? const MessageAttachment.unknown()
      : _messageAttachmentFromJson(json['attachment']),
  $type: json['type'] as String?,
);

Map<String, dynamic> _$MessagePartFileToJson(MessagePartFile instance) =>
    <String, dynamic>{
      'id': instance.id,
      'sessionID': instance.sessionID,
      'messageID': instance.messageID,
      'attachment': instance.attachment.toJson(),
      'type': instance.$type,
    };

MessagePartSnapshot _$MessagePartSnapshotFromJson(Map json) =>
    MessagePartSnapshot(
      id: json['id'] as String,
      sessionID: json['sessionID'] as String,
      messageID: json['messageID'] as String,
      $type: json['type'] as String?,
    );

Map<String, dynamic> _$MessagePartSnapshotToJson(
  MessagePartSnapshot instance,
) => <String, dynamic>{
  'id': instance.id,
  'sessionID': instance.sessionID,
  'messageID': instance.messageID,
  'type': instance.$type,
};

MessagePartPatch _$MessagePartPatchFromJson(Map json) => MessagePartPatch(
  id: json['id'] as String,
  sessionID: json['sessionID'] as String,
  messageID: json['messageID'] as String,
  $type: json['type'] as String?,
);

Map<String, dynamic> _$MessagePartPatchToJson(MessagePartPatch instance) =>
    <String, dynamic>{
      'id': instance.id,
      'sessionID': instance.sessionID,
      'messageID': instance.messageID,
      'type': instance.$type,
    };

MessagePartAgent _$MessagePartAgentFromJson(Map json) => MessagePartAgent(
  id: json['id'] as String,
  sessionID: json['sessionID'] as String,
  messageID: json['messageID'] as String,
  agentName: json['agentName'] as String? ?? "",
  $type: json['type'] as String?,
);

Map<String, dynamic> _$MessagePartAgentToJson(MessagePartAgent instance) =>
    <String, dynamic>{
      'id': instance.id,
      'sessionID': instance.sessionID,
      'messageID': instance.messageID,
      'agentName': instance.agentName,
      'type': instance.$type,
    };

MessagePartRetry _$MessagePartRetryFromJson(Map json) => MessagePartRetry(
  id: json['id'] as String,
  sessionID: json['sessionID'] as String,
  messageID: json['messageID'] as String,
  attempt: (json['attempt'] as num?)?.toInt() ?? 0,
  retryError: json['retryError'] as String? ?? "",
  $type: json['type'] as String?,
);

Map<String, dynamic> _$MessagePartRetryToJson(MessagePartRetry instance) =>
    <String, dynamic>{
      'id': instance.id,
      'sessionID': instance.sessionID,
      'messageID': instance.messageID,
      'attempt': instance.attempt,
      'retryError': instance.retryError,
      'type': instance.$type,
    };

MessagePartCompaction _$MessagePartCompactionFromJson(Map json) =>
    MessagePartCompaction(
      id: json['id'] as String,
      sessionID: json['sessionID'] as String,
      messageID: json['messageID'] as String,
      $type: json['type'] as String?,
    );

Map<String, dynamic> _$MessagePartCompactionToJson(
  MessagePartCompaction instance,
) => <String, dynamic>{
  'id': instance.id,
  'sessionID': instance.sessionID,
  'messageID': instance.messageID,
  'type': instance.$type,
};

MessageAttachmentInlineImage _$MessageAttachmentInlineImageFromJson(Map json) =>
    MessageAttachmentInlineImage(
      mime: json['mime'] as String,
      base64: json['base64'] as String,
      filename: json['filename'] as String?,
      $type: json['source'] as String?,
    );

Map<String, dynamic> _$MessageAttachmentInlineImageToJson(
  MessageAttachmentInlineImage instance,
) => <String, dynamic>{
  'mime': instance.mime,
  'base64': instance.base64,
  'filename': ?instance.filename,
  'source': instance.$type,
};

MessageAttachmentRemoteUrl _$MessageAttachmentRemoteUrlFromJson(Map json) =>
    MessageAttachmentRemoteUrl(
      mime: json['mime'] as String,
      url: json['url'] as String,
      filename: json['filename'] as String?,
      $type: json['source'] as String?,
    );

Map<String, dynamic> _$MessageAttachmentRemoteUrlToJson(
  MessageAttachmentRemoteUrl instance,
) => <String, dynamic>{
  'mime': instance.mime,
  'url': instance.url,
  'filename': ?instance.filename,
  'source': instance.$type,
};

MessageAttachmentStoredImage _$MessageAttachmentStoredImageFromJson(Map json) =>
    MessageAttachmentStoredImage(
      attachmentId: json['attachmentId'] as String,
      bridgeId: json['bridgeId'] as String,
      mime: json['mime'] as String,
      filename: json['filename'] as String?,
      byteLength: (json['byteLength'] as num).toInt(),
      $type: json['source'] as String?,
    );

Map<String, dynamic> _$MessageAttachmentStoredImageToJson(
  MessageAttachmentStoredImage instance,
) => <String, dynamic>{
  'attachmentId': instance.attachmentId,
  'bridgeId': instance.bridgeId,
  'mime': instance.mime,
  'filename': ?instance.filename,
  'byteLength': instance.byteLength,
  'source': instance.$type,
};

MessageAttachmentMetadata _$MessageAttachmentMetadataFromJson(Map json) =>
    MessageAttachmentMetadata(
      mime: json['mime'] as String,
      filename: json['filename'] as String?,
      $type: json['source'] as String?,
    );

Map<String, dynamic> _$MessageAttachmentMetadataToJson(
  MessageAttachmentMetadata instance,
) => <String, dynamic>{
  'mime': instance.mime,
  'filename': ?instance.filename,
  'source': instance.$type,
};

MessageAttachmentUnknown _$MessageAttachmentUnknownFromJson(Map json) =>
    MessageAttachmentUnknown($type: json['source'] as String?);

Map<String, dynamic> _$MessageAttachmentUnknownToJson(
  MessageAttachmentUnknown instance,
) => <String, dynamic>{'source': instance.$type};

_ToolState _$ToolStateFromJson(Map json) => _ToolState(
  status: $enumDecode(
    _$ToolStatusEnumMap,
    json['status'],
    unknownValue: ToolStatus.unknown,
  ),
  title: json['title'] as String?,
  shellCommand: json['shellCommand'] as String?,
  output: json['output'] as String?,
  error: json['error'] as String?,
  attachments: json['attachments'] == null
      ? const <MessageAttachment>[]
      : _messageAttachmentsFromJson(json['attachments']),
);

Map<String, dynamic> _$ToolStateToJson(_ToolState instance) =>
    <String, dynamic>{
      'status': _$ToolStatusEnumMap[instance.status]!,
      'title': ?instance.title,
      'shellCommand': ?instance.shellCommand,
      'output': ?instance.output,
      'error': ?instance.error,
      'attachments': instance.attachments.map((e) => e.toJson()).toList(),
    };

const _$ToolStatusEnumMap = {
  ToolStatus.pending: 'pending',
  ToolStatus.running: 'running',
  ToolStatus.completed: 'completed',
  ToolStatus.error: 'error',
  ToolStatus.cancelled: 'cancelled',
  ToolStatus.unknown: 'unknown',
};
