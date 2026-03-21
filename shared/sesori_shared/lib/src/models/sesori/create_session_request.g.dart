// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'create_session_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_CreateSessionRequest _$CreateSessionRequestFromJson(Map json) =>
    _CreateSessionRequest(
      projectId: json['projectId'] as String,
      parentSessionId: json['parentSessionId'] as String?,
    );

Map<String, dynamic> _$CreateSessionRequestToJson(
  _CreateSessionRequest instance,
) => <String, dynamic>{
  'projectId': instance.projectId,
  'parentSessionId': instance.parentSessionId,
};
