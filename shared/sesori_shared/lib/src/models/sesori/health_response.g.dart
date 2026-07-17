// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'health_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_HealthResponse _$HealthResponseFromJson(Map json) => _HealthResponse(
  healthy: json['healthy'] as bool,
  version: json['version'] as String,
  plugins:
      (json['plugins'] as List<dynamic>?)
          ?.map(
            (e) => PluginHealth.fromJson(Map<String, dynamic>.from(e as Map)),
          )
          .toList() ??
      const <PluginHealth>[],
  filesystemAccessDegraded: json['filesystemAccessDegraded'] as bool?,
);

Map<String, dynamic> _$HealthResponseToJson(_HealthResponse instance) => <String, dynamic>{
  'healthy': instance.healthy,
  'version': instance.version,
  'plugins': instance.plugins.map((e) => e.toJson()).toList(),
  'filesystemAccessDegraded': ?instance.filesystemAccessDegraded,
};

_PluginHealth _$PluginHealthFromJson(Map json) => _PluginHealth(
  pluginId: json['pluginId'] as String,
  healthy: json['healthy'] as bool,
);

Map<String, dynamic> _$PluginHealthToJson(_PluginHealth instance) => <String, dynamic>{
  'pluginId': instance.pluginId,
  'healthy': instance.healthy,
};
