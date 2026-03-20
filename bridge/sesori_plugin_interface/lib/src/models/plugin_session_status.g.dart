// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'plugin_session_status.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Map<String, dynamic> _$PluginSessionStatusIdleToJson(
  PluginSessionStatusIdle instance,
) => <String, dynamic>{'runtimeType': instance.$type};

Map<String, dynamic> _$PluginSessionStatusBusyToJson(
  PluginSessionStatusBusy instance,
) => <String, dynamic>{'runtimeType': instance.$type};

Map<String, dynamic> _$PluginSessionStatusRetryToJson(
  PluginSessionStatusRetry instance,
) => <String, dynamic>{
  'attempt': instance.attempt,
  'message': instance.message,
  'next': instance.next,
  'runtimeType': instance.$type,
};
