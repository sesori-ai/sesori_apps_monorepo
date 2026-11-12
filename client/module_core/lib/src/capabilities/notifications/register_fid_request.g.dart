// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'register_fid_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_RegisterFidRequest _$RegisterFidRequestFromJson(Map json) =>
    _RegisterFidRequest(
      fid: json['fid'] as String,
      platform: $enumDecode(_$DevicePlatformEnumMap, json['platform']),
      deviceId: json['deviceId'] as String?,
    );

Map<String, dynamic> _$RegisterFidRequestToJson(_RegisterFidRequest instance) =>
    <String, dynamic>{
      'fid': instance.fid,
      'platform': _$DevicePlatformEnumMap[instance.platform]!,
      'deviceId': ?instance.deviceId,
    };

const _$DevicePlatformEnumMap = {
  DevicePlatform.ios: 'ios',
  DevicePlatform.android: 'android',
  DevicePlatform.macos: 'macos',
};
