// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'device_info.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_DeviceInfo _$DeviceInfoFromJson(Map json) => _DeviceInfo(
  name: json['name'] as String,
  osVersion: json['osVersion'] as String?,
  appVersion: json['appVersion'] as String?,
);

Map<String, dynamic> _$DeviceInfoToJson(_DeviceInfo instance) =>
    <String, dynamic>{
      'name': instance.name,
      'osVersion': ?instance.osVersion,
      'appVersion': ?instance.appVersion,
    };
