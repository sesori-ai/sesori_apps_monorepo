// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'move_session_pin_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_MoveSessionPinRequest _$MoveSessionPinRequestFromJson(Map json) =>
    _MoveSessionPinRequest(
      sessionId: json['sessionId'] as String,
      afterSessionId: json['afterSessionId'] as String?,
    );

Map<String, dynamic> _$MoveSessionPinRequestToJson(
  _MoveSessionPinRequest instance,
) => <String, dynamic>{
  'sessionId': instance.sessionId,
  'afterSessionId': ?instance.afterSessionId,
};

_MoveSessionPinResponse _$MoveSessionPinResponseFromJson(Map json) =>
    _MoveSessionPinResponse(
      sessions: (json['sessions'] as List<dynamic>)
          .map((e) => Session.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
    );

Map<String, dynamic> _$MoveSessionPinResponseToJson(
  _MoveSessionPinResponse instance,
) => <String, dynamic>{
  'sessions': instance.sessions.map((e) => e.toJson()).toList(),
};
