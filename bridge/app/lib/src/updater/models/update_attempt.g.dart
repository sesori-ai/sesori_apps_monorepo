// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'update_attempt.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_UpdateAttempt _$UpdateAttemptFromJson(Map json) => _UpdateAttempt(
  fromVersion: json['fromVersion'] as String,
  toVersion: json['toVersion'] as String,
  startedAt: DateTime.parse(json['startedAt'] as String),
  status: $enumDecode(_$UpdateAttemptStatusEnumMap, json['status']),
  reason: json['reason'] as String?,
);

Map<String, dynamic> _$UpdateAttemptToJson(_UpdateAttempt instance) =>
    <String, dynamic>{
      'fromVersion': instance.fromVersion,
      'toVersion': instance.toVersion,
      'startedAt': instance.startedAt.toIso8601String(),
      'status': _$UpdateAttemptStatusEnumMap[instance.status]!,
      'reason': ?instance.reason,
    };

const _$UpdateAttemptStatusEnumMap = {
  UpdateAttemptStatus.inFlight: 'inFlight',
  UpdateAttemptStatus.appliedPendingActivation: 'appliedPendingActivation',
  UpdateAttemptStatus.failed: 'failed',
};
