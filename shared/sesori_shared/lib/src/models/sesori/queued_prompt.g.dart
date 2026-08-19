// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'queued_prompt.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_QueuedSessionPrompt _$QueuedSessionPromptFromJson(Map json) =>
    _QueuedSessionPrompt(
      id: json['id'] as String,
      text: json['text'] as String?,
      command: json['command'] as String?,
      attachmentCount: (json['attachmentCount'] as num?)?.toInt() ?? 0,
      createdAt: (json['createdAt'] as num).toInt(),
    );

Map<String, dynamic> _$QueuedSessionPromptToJson(
  _QueuedSessionPrompt instance,
) => <String, dynamic>{
  'id': instance.id,
  'text': ?instance.text,
  'command': ?instance.command,
  'attachmentCount': instance.attachmentCount,
  'createdAt': instance.createdAt,
};

_QueuedPromptResponse _$QueuedPromptResponseFromJson(Map json) =>
    _QueuedPromptResponse(
      data: (json['data'] as List<dynamic>)
          .map(
            (e) => QueuedSessionPrompt.fromJson(
              Map<String, dynamic>.from(e as Map),
            ),
          )
          .toList(),
    );

Map<String, dynamic> _$QueuedPromptResponseToJson(
  _QueuedPromptResponse instance,
) => <String, dynamic>{'data': instance.data.map((e) => e.toJson()).toList()};

_CancelQueuedPromptRequest _$CancelQueuedPromptRequestFromJson(Map json) =>
    _CancelQueuedPromptRequest(
      sessionId: json['sessionId'] as String,
      promptId: json['promptId'] as String,
    );

Map<String, dynamic> _$CancelQueuedPromptRequestToJson(
  _CancelQueuedPromptRequest instance,
) => <String, dynamic>{
  'sessionId': instance.sessionId,
  'promptId': instance.promptId,
};
