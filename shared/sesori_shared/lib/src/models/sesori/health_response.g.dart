// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'health_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_HealthResponse _$HealthResponseFromJson(Map json) => _HealthResponse(
  healthy: json['healthy'] as bool,
  version: json['version'] as String,
  filesystemAccessDegraded: json['filesystemAccessDegraded'] as bool,
  bridgeKind:
      $enumDecodeNullable(
        _$BridgeKindEnumMap,
        json['bridgeKind'],
        unknownValue: BridgeKind.cli,
      ) ??
      BridgeKind.cli,
);

Map<String, dynamic> _$HealthResponseToJson(_HealthResponse instance) =>
    <String, dynamic>{
      'healthy': instance.healthy,
      'version': instance.version,
      'filesystemAccessDegraded': instance.filesystemAccessDegraded,
      'bridgeKind': _$BridgeKindEnumMap[instance.bridgeKind]!,
    };

const _$BridgeKindEnumMap = {
  BridgeKind.cli: 'cli',
  BridgeKind.desktop: 'desktop',
};
