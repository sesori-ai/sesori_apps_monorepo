// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'session_status.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SessionStatusIdle _$SessionStatusIdleFromJson(Map json) => SessionStatusIdle($type: json['type'] as String?);

Map<String, dynamic> _$SessionStatusIdleToJson(SessionStatusIdle instance) => <String, dynamic>{'type': instance.$type};

SessionStatusBusy _$SessionStatusBusyFromJson(Map json) => SessionStatusBusy($type: json['type'] as String?);

Map<String, dynamic> _$SessionStatusBusyToJson(SessionStatusBusy instance) => <String, dynamic>{'type': instance.$type};

SessionStatusRetry _$SessionStatusRetryFromJson(Map json) => SessionStatusRetry(
  attempt: (json['attempt'] as num).toInt(),
  message: json['message'] as String,
  next: (json['next'] as num).toInt(),
  $type: json['type'] as String?,
);

Map<String, dynamic> _$SessionStatusRetryToJson(SessionStatusRetry instance) => <String, dynamic>{
  'attempt': instance.attempt,
  'message': instance.message,
  'next': instance.next,
  'type': instance.$type,
};
