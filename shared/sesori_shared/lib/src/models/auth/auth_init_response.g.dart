// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'auth_init_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_AuthInitResponse _$AuthInitResponseFromJson(Map json) => _AuthInitResponse(
  authUrl: json['authUrl'] as String,
  state: json['state'] as String,
  userCode: json['userCode'] as String,
  expiresIn: (json['expiresIn'] as num).toInt(),
);

Map<String, dynamic> _$AuthInitResponseToJson(_AuthInitResponse instance) =>
    <String, dynamic>{
      'authUrl': instance.authUrl,
      'state': instance.state,
      'userCode': instance.userCode,
      'expiresIn': instance.expiresIn,
    };
