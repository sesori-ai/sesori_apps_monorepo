// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'fork_session_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ForkSessionRequest _$ForkSessionRequestFromJson(Map json) =>
    _ForkSessionRequest(
      sessionId: json['sessionId'] as String,
      point: ForkPoint.fromJson(
        Map<String, dynamic>.from(json['point'] as Map),
      ),
    );

Map<String, dynamic> _$ForkSessionRequestToJson(_ForkSessionRequest instance) =>
    <String, dynamic>{
      'sessionId': instance.sessionId,
      'point': instance.point.toJson(),
    };

ForkPointAfterMessage _$ForkPointAfterMessageFromJson(Map json) =>
    ForkPointAfterMessage(
      messageId: json['messageId'] as String,
      $type: json['type'] as String?,
    );

Map<String, dynamic> _$ForkPointAfterMessageToJson(
  ForkPointAfterMessage instance,
) => <String, dynamic>{'messageId': instance.messageId, 'type': instance.$type};

ForkPointBeforeMessage _$ForkPointBeforeMessageFromJson(Map json) =>
    ForkPointBeforeMessage(
      messageId: json['messageId'] as String,
      $type: json['type'] as String?,
    );

Map<String, dynamic> _$ForkPointBeforeMessageToJson(
  ForkPointBeforeMessage instance,
) => <String, dynamic>{'messageId': instance.messageId, 'type': instance.$type};

ForkPointLatest _$ForkPointLatestFromJson(Map json) =>
    ForkPointLatest($type: json['type'] as String?);

Map<String, dynamic> _$ForkPointLatestToJson(ForkPointLatest instance) =>
    <String, dynamic>{'type': instance.$type};
