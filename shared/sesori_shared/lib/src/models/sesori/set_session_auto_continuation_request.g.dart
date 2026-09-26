// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'set_session_auto_continuation_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_SetSessionAutoContinuationRequest _$SetSessionAutoContinuationRequestFromJson(
  Map json,
) => _SetSessionAutoContinuationRequest(
  sessionId: json['sessionId'] as String,
  enabled: json['enabled'] as bool,
);

Map<String, dynamic> _$SetSessionAutoContinuationRequestToJson(
  _SetSessionAutoContinuationRequest instance,
) => <String, dynamic>{
  'sessionId': instance.sessionId,
  'enabled': instance.enabled,
};
