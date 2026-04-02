// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'send_command_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_SendCommandRequest _$SendCommandRequestFromJson(Map json) =>
    _SendCommandRequest(
      sessionId: json['sessionId'] as String,
      command: json['command'] as String,
      arguments: json['arguments'] as String,
    );

Map<String, dynamic> _$SendCommandRequestToJson(_SendCommandRequest instance) =>
    <String, dynamic>{
      'sessionId': instance.sessionId,
      'command': instance.command,
      'arguments': instance.arguments,
    };
