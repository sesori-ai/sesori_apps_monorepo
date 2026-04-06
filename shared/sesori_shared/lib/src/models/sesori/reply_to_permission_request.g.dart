// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'reply_to_permission_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ReplyToPermissionRequest _$ReplyToPermissionRequestFromJson(Map json) =>
    _ReplyToPermissionRequest(
      requestId: json['requestId'] as String,
      sessionId: json['sessionId'] as String,
      reply: $enumDecode(_$PermissionReplyEnumMap, json['reply']),
    );

Map<String, dynamic> _$ReplyToPermissionRequestToJson(
  _ReplyToPermissionRequest instance,
) => <String, dynamic>{
  'requestId': instance.requestId,
  'sessionId': instance.sessionId,
  'reply': _$PermissionReplyEnumMap[instance.reply]!,
};

const _$PermissionReplyEnumMap = {
  PermissionReply.once: 'once',
  PermissionReply.always: 'always',
  PermissionReply.reject: 'reject',
};
