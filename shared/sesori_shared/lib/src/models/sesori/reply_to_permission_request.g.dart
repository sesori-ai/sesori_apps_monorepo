// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'reply_to_permission_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ReplyToPermissionRequest _$ReplyToPermissionRequestFromJson(Map json) =>
    _ReplyToPermissionRequest(
      requestId: json['requestId'] as String,
      sessionId: json['sessionId'] as String,
      response: json['response'] as String,
    );

Map<String, dynamic> _$ReplyToPermissionRequestToJson(
  _ReplyToPermissionRequest instance,
) => <String, dynamic>{
  'requestId': instance.requestId,
  'sessionId': instance.sessionId,
  'response': instance.response,
};
