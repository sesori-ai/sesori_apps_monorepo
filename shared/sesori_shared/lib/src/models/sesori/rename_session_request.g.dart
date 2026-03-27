// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'rename_session_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_RenameSessionRequest _$RenameSessionRequestFromJson(Map json) =>
    _RenameSessionRequest(
      sessionId: json['sessionId'] as String,
      title: json['title'] as String,
    );

Map<String, dynamic> _$RenameSessionRequestToJson(
  _RenameSessionRequest instance,
) => <String, dynamic>{
  'sessionId': instance.sessionId,
  'title': instance.title,
};
