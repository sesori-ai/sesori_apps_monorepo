// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'session_wake_up.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_SessionWakeUp _$SessionWakeUpFromJson(Map json) => _SessionWakeUp(
  id: json['id'] as String,
  nextDueAt: (json['nextDueAt'] as num).toInt(),
  label: json['label'] as String,
  repeats: json['repeats'] as bool,
  runsCommand: json['runsCommand'] as bool,
);

Map<String, dynamic> _$SessionWakeUpToJson(_SessionWakeUp instance) =>
    <String, dynamic>{
      'id': instance.id,
      'nextDueAt': instance.nextDueAt,
      'label': instance.label,
      'repeats': instance.repeats,
      'runsCommand': instance.runsCommand,
    };

SessionArmingUnreported _$SessionArmingUnreportedFromJson(Map json) =>
    SessionArmingUnreported($type: json['kind'] as String?);

Map<String, dynamic> _$SessionArmingUnreportedToJson(
  SessionArmingUnreported instance,
) => <String, dynamic>{'kind': instance.$type};

SessionArmingNotArmed _$SessionArmingNotArmedFromJson(Map json) =>
    SessionArmingNotArmed($type: json['kind'] as String?);

Map<String, dynamic> _$SessionArmingNotArmedToJson(
  SessionArmingNotArmed instance,
) => <String, dynamic>{'kind': instance.$type};

SessionArmingArmed _$SessionArmingArmedFromJson(Map json) => SessionArmingArmed(
  name: json['name'] as String,
  nextAt: (json['nextAt'] as num).toInt(),
  $type: json['kind'] as String?,
);

Map<String, dynamic> _$SessionArmingArmedToJson(SessionArmingArmed instance) =>
    <String, dynamic>{
      'name': instance.name,
      'nextAt': instance.nextAt,
      'kind': instance.$type,
    };
