// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'session_interruption.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_SessionInterruption _$SessionInterruptionFromJson(Map json) =>
    _SessionInterruption(
      afterMessageId: json['afterMessageId'] as String,
      unacknowledged: json['unacknowledged'] as bool,
    );

Map<String, dynamic> _$SessionInterruptionToJson(
  _SessionInterruption instance,
) => <String, dynamic>{
  'afterMessageId': instance.afterMessageId,
  'unacknowledged': instance.unacknowledged,
};
