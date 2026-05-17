// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'bridge_startup_lock.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_BridgeStartupLock _$BridgeStartupLockFromJson(Map json) => _BridgeStartupLock(
  bridgePid: (json['bridgePid'] as num).toInt(),
  bridgeStartMarker: json['bridgeStartMarker'] as String?,
);

Map<String, dynamic> _$BridgeStartupLockToJson(_BridgeStartupLock instance) =>
    <String, dynamic>{
      'bridgePid': instance.bridgePid,
      'bridgeStartMarker': instance.bridgeStartMarker,
    };
