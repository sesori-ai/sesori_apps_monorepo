// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'message_part.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_MessagePart _$MessagePartFromJson(Map json) => _MessagePart(
  id: json['id'] as String,
  sessionID: json['sessionID'] as String,
  messageID: json['messageID'] as String,
  type: $enumDecode(_$MessagePartTypeEnumMap, json['type']),
  text: json['text'] as String?,
  tool: json['tool'] as String?,
  state: json['state'] == null
      ? null
      : ToolState.fromJson(Map<String, dynamic>.from(json['state'] as Map)),
  prompt: json['prompt'] as String?,
  description: json['description'] as String?,
  agent: json['agent'] as String?,
  childSessionID: json['childSessionID'] as String?,
  agentName: json['agentName'] as String?,
  attempt: (json['attempt'] as num?)?.toInt(),
  retryError: json['retryError'] as String?,
  attachment: _messageAttachmentFromJson(json['attachment']),
);

Map<String, dynamic> _$MessagePartToJson(_MessagePart instance) =>
    <String, dynamic>{
      'id': instance.id,
      'sessionID': instance.sessionID,
      'messageID': instance.messageID,
      'type': _$MessagePartTypeEnumMap[instance.type]!,
      'text': ?instance.text,
      'tool': ?instance.tool,
      'state': ?instance.state?.toJson(),
      'prompt': ?instance.prompt,
      'description': ?instance.description,
      'agent': ?instance.agent,
      'childSessionID': ?instance.childSessionID,
      'agentName': ?instance.agentName,
      'attempt': ?instance.attempt,
      'retryError': ?instance.retryError,
      'attachment': ?instance.attachment?.toJson(),
    };

const _$MessagePartTypeEnumMap = {
  MessagePartType.text: 'text',
  MessagePartType.reasoning: 'reasoning',
  MessagePartType.tool: 'tool',
  MessagePartType.subtask: 'subtask',
  MessagePartType.stepStart: 'step-start',
  MessagePartType.stepFinish: 'step-finish',
  MessagePartType.file: 'file',
  MessagePartType.snapshot: 'snapshot',
  MessagePartType.patch: 'patch',
  MessagePartType.agent: 'agent',
  MessagePartType.retry: 'retry',
  MessagePartType.compaction: 'compaction',
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
