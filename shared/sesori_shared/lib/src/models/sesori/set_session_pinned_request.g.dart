// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'set_session_pinned_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_SetSessionPinnedRequest _$SetSessionPinnedRequestFromJson(Map json) =>
    _SetSessionPinnedRequest(
      sessionId: json['sessionId'] as String,
      pinned: json['pinned'] as bool,
    );

Map<String, dynamic> _$SetSessionPinnedRequestToJson(
  _SetSessionPinnedRequest instance,
) => <String, dynamic>{
  'sessionId': instance.sessionId,
  'pinned': instance.pinned,
};
