// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'session_tool_output.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_SessionToolOutputRequest _$SessionToolOutputRequestFromJson(Map json) =>
    _SessionToolOutputRequest(
      sessionId: json['sessionId'] as String,
      messageId: json['messageId'] as String,
      partId: json['partId'] as String,
    );

Map<String, dynamic> _$SessionToolOutputRequestToJson(
  _SessionToolOutputRequest instance,
) => <String, dynamic>{
  'sessionId': instance.sessionId,
  'messageId': instance.messageId,
  'partId': instance.partId,
};

_SessionToolOutputResponse _$SessionToolOutputResponseFromJson(Map json) =>
    _SessionToolOutputResponse(
      output: json['output'] as String?,
      error: json['error'] as String?,
    );

Map<String, dynamic> _$SessionToolOutputResponseToJson(
  _SessionToolOutputResponse instance,
) => <String, dynamic>{'output': ?instance.output, 'error': ?instance.error};
