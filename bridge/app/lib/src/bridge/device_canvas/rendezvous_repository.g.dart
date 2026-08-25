// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'rendezvous_repository.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_DeviceCanvasRendezvous _$DeviceCanvasRendezvousFromJson(Map json) =>
    _DeviceCanvasRendezvous(
      protocolVersion: (json['protocolVersion'] as num).toInt(),
      port: (json['port'] as num).toInt(),
      bearerSecret: json['bearerSecret'] as String,
      bridgeId: json['bridgeId'] as String,
      processGeneration: json['processGeneration'] as String,
    );

Map<String, dynamic> _$DeviceCanvasRendezvousToJson(
  _DeviceCanvasRendezvous instance,
) => <String, dynamic>{
  'protocolVersion': instance.protocolVersion,
  'port': instance.port,
  'bearerSecret': instance.bearerSecret,
  'bridgeId': instance.bridgeId,
  'processGeneration': instance.processGeneration,
};
