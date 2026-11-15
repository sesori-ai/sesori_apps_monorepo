// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'send_to_session_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_SendToSessionRequest _$SendToSessionRequestFromJson(Map json) =>
    _SendToSessionRequest(
      sourceSessionId: json['sourceSessionId'] as String,
      targetSessionId: json['targetSessionId'] as String,
    );

Map<String, dynamic> _$SendToSessionRequestToJson(
  _SendToSessionRequest instance,
) => <String, dynamic>{
  'sourceSessionId': instance.sourceSessionId,
  'targetSessionId': instance.targetSessionId,
};
