// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'register_bridge_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_RegisterBridgeRequest _$RegisterBridgeRequestFromJson(Map json) =>
    _RegisterBridgeRequest(
      name: json['name'] as String,
      platform: json['platform'] as String,
      bridgeId: json['bridgeId'] as String?,
      hostKey: json['hostKey'] as String?,
      kind: $enumDecode(_$BridgeKindEnumMap, json['kind']),
    );

Map<String, dynamic> _$RegisterBridgeRequestToJson(
  _RegisterBridgeRequest instance,
) => <String, dynamic>{
  'name': instance.name,
  'platform': instance.platform,
  'bridgeId': ?instance.bridgeId,
  'hostKey': ?instance.hostKey,
  'kind': _$BridgeKindEnumMap[instance.kind]!,
};

const _$BridgeKindEnumMap = {
  BridgeKind.cli: 'cli',
  BridgeKind.desktop: 'desktop',
};
