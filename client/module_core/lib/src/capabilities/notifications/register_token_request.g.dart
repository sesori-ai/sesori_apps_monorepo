// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'register_token_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_RegisterTokenRequest _$RegisterTokenRequestFromJson(Map json) =>
    _RegisterTokenRequest(
      token: json['token'] as String,
      platform: $enumDecode(_$DevicePlatformEnumMap, json['platform']),
      deviceId: json['deviceId'] as String?,
    );

Map<String, dynamic> _$RegisterTokenRequestToJson(
  _RegisterTokenRequest instance,
) => <String, dynamic>{
  'token': instance.token,
  'platform': _$DevicePlatformEnumMap[instance.platform]!,
  'deviceId': ?instance.deviceId,
};

const _$DevicePlatformEnumMap = {
  DevicePlatform.ios: 'ios',
  DevicePlatform.android: 'android',
  DevicePlatform.macos: 'macos',
};
