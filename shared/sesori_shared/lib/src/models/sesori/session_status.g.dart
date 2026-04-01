// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'session_status.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_SessionStatusResponse _$SessionStatusResponseFromJson(Map json) =>
    _SessionStatusResponse(
      statuses: (json['statuses'] as Map).map(
        (k, e) => MapEntry(
          k as String,
          SessionStatus.fromJson(Map<String, dynamic>.from(e as Map)),
        ),
      ),
    );

Map<String, dynamic> _$SessionStatusResponseToJson(
  _SessionStatusResponse instance,
) => <String, dynamic>{
  'statuses': instance.statuses.map((k, e) => MapEntry(k, e.toJson())),
};

SessionStatusIdle _$SessionStatusIdleFromJson(Map json) =>
    SessionStatusIdle($type: json['type'] as String?);

Map<String, dynamic> _$SessionStatusIdleToJson(SessionStatusIdle instance) =>
    <String, dynamic>{'type': instance.$type};

SessionStatusBusy _$SessionStatusBusyFromJson(Map json) =>
    SessionStatusBusy($type: json['type'] as String?);

Map<String, dynamic> _$SessionStatusBusyToJson(SessionStatusBusy instance) =>
    <String, dynamic>{'type': instance.$type};

SessionStatusRetry _$SessionStatusRetryFromJson(Map json) => SessionStatusRetry(
  attempt: (json['attempt'] as num).toInt(),
  message: json['message'] as String,
  next: (json['next'] as num).toInt(),
  $type: json['type'] as String?,
);

Map<String, dynamic> _$SessionStatusRetryToJson(SessionStatusRetry instance) =>
    <String, dynamic>{
      'attempt': instance.attempt,
      'message': instance.message,
      'next': instance.next,
      'type': instance.$type,
    };
