// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'cancel_session_wake_up_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_CancelSessionWakeUpRequest _$CancelSessionWakeUpRequestFromJson(Map json) =>
    _CancelSessionWakeUpRequest(
      sessionId: json['sessionId'] as String,
      wakeUpId: json['wakeUpId'] as String,
    );

Map<String, dynamic> _$CancelSessionWakeUpRequestToJson(
  _CancelSessionWakeUpRequest instance,
) => <String, dynamic>{
  'sessionId': instance.sessionId,
  'wakeUpId': instance.wakeUpId,
};
