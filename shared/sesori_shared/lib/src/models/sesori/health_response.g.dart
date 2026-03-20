// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'health_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_HealthResponse _$HealthResponseFromJson(Map json) => _HealthResponse(
  healthy: json['healthy'] as bool,
  version: json['version'] as String,
);

Map<String, dynamic> _$HealthResponseToJson(_HealthResponse instance) =>
    <String, dynamic>{'healthy': instance.healthy, 'version': instance.version};
