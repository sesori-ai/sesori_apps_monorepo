// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'auth_init_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_AuthInitRequest _$AuthInitRequestFromJson(Map json) => _AuthInitRequest(
  clientType: $enumDecode(_$AuthClientTypeEnumMap, json['clientType']),
  device: DeviceInfo.fromJson(Map<String, dynamic>.from(json['device'] as Map)),
);

Map<String, dynamic> _$AuthInitRequestToJson(_AuthInitRequest instance) =>
    <String, dynamic>{
      'clientType': _$AuthClientTypeEnumMap[instance.clientType]!,
      'device': instance.device.toJson(),
    };

const _$AuthClientTypeEnumMap = {
  AuthClientType.bridge: 'bridge',
  AuthClientType.app: 'app',
  AuthClientType.bridgeMacos: 'bridge_macos',
  AuthClientType.bridgeWindows: 'bridge_windows',
  AuthClientType.bridgeLinux: 'bridge_linux',
  AuthClientType.appIos: 'app_ios',
  AuthClientType.appAndroid: 'app_android',
  AuthClientType.appMacos: 'app_macos',
  AuthClientType.appWindows: 'app_windows',
  AuthClientType.appLinux: 'app_linux',
};
