// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'health_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_HealthResponse _$HealthResponseFromJson(Map json) => _HealthResponse(
  healthy: json['healthy'] as bool,
  version: json['version'] as String,
  serverManaged: json['serverManaged'] as bool?,
  serverState: $enumDecodeNullable(
    _$ServerStateKindEnumMap,
    json['serverState'],
  ),
);

Map<String, dynamic> _$HealthResponseToJson(_HealthResponse instance) =>
    <String, dynamic>{
      'healthy': instance.healthy,
      'version': instance.version,
      'serverManaged': instance.serverManaged,
      'serverState': _$ServerStateKindEnumMap[instance.serverState],
    };

const _$ServerStateKindEnumMap = {
  ServerStateKind.running: 'running',
  ServerStateKind.unreachable: 'unreachable',
  ServerStateKind.restarting: 'restarting',
  ServerStateKind.failed: 'failed',
};
