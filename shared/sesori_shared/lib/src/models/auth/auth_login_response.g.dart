// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'auth_login_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_AuthLoginResponse _$AuthLoginResponseFromJson(Map json) => _AuthLoginResponse(
  accessToken: json['accessToken'] as String,
  refreshToken: json['refreshToken'] as String,
  user: AuthUser.fromJson(Map<String, dynamic>.from(json['user'] as Map)),
  accountStatus: $enumDecode(
    _$AccountStatusEnumMap,
    json['accountStatus'],
    unknownValue: AccountStatus.unknown,
  ),
);

const _$AccountStatusEnumMap = {
  AccountStatus.created: 'created',
  AccountStatus.existing: 'existing',
  AccountStatus.unknown: 'unknown',
};
