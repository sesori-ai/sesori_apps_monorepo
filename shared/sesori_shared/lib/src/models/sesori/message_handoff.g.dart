// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'message_handoff.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MessageHandoffSent _$MessageHandoffSentFromJson(Map json) => MessageHandoffSent(
  targetSessionId: json['targetSessionId'] as String,
  targetTitle: json['targetTitle'] as String?,
  $type: json['kind'] as String?,
);

Map<String, dynamic> _$MessageHandoffSentToJson(MessageHandoffSent instance) =>
    <String, dynamic>{
      'targetSessionId': instance.targetSessionId,
      'targetTitle': ?instance.targetTitle,
      'kind': instance.$type,
    };

MessageHandoffNotSent _$MessageHandoffNotSentFromJson(Map json) =>
    MessageHandoffNotSent(
      targetSessionId: json['targetSessionId'] as String,
      targetTitle: json['targetTitle'] as String?,
      $type: json['kind'] as String?,
    );

Map<String, dynamic> _$MessageHandoffNotSentToJson(
  MessageHandoffNotSent instance,
) => <String, dynamic>{
  'targetSessionId': instance.targetSessionId,
  'targetTitle': ?instance.targetTitle,
  'kind': instance.$type,
};

MessageHandoffReceived _$MessageHandoffReceivedFromJson(Map json) =>
    MessageHandoffReceived(
      sourceSessionId: json['sourceSessionId'] as String,
      sourceTitle: json['sourceTitle'] as String?,
      summary: json['summary'] as String,
      transcriptPath: json['transcriptPath'] as String,
      $type: json['kind'] as String?,
    );

Map<String, dynamic> _$MessageHandoffReceivedToJson(
  MessageHandoffReceived instance,
) => <String, dynamic>{
  'sourceSessionId': instance.sourceSessionId,
  'sourceTitle': ?instance.sourceTitle,
  'summary': instance.summary,
  'transcriptPath': instance.transcriptPath,
  'kind': instance.$type,
};

MessageHandoffUnknown _$MessageHandoffUnknownFromJson(Map json) =>
    MessageHandoffUnknown($type: json['kind'] as String?);

Map<String, dynamic> _$MessageHandoffUnknownToJson(
  MessageHandoffUnknown instance,
) => <String, dynamic>{'kind': instance.$type};
