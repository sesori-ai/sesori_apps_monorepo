// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'mark_session_seen_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_MarkSessionSeenRequest _$MarkSessionSeenRequestFromJson(Map json) =>
    _MarkSessionSeenRequest(
      sessionId: json['sessionId'] as String,
      read: json['read'] as bool,
    );

Map<String, dynamic> _$MarkSessionSeenRequestToJson(
  _MarkSessionSeenRequest instance,
) => <String, dynamic>{'sessionId': instance.sessionId, 'read': instance.read};
