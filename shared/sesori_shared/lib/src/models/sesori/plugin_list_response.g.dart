// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'plugin_list_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_PluginMetadata _$PluginMetadataFromJson(Map json) => _PluginMetadata(
  id: json['id'] as String,
  displayName: json['displayName'] as String,
  isDefault: json['isDefault'] as bool,
  state: $enumDecode(
    _$PluginLifecycleStateEnumMap,
    json['state'],
    unknownValue: PluginLifecycleState.unavailable,
  ),
  actionHint: json['actionHint'] as String?,
);

Map<String, dynamic> _$PluginMetadataToJson(_PluginMetadata instance) =>
    <String, dynamic>{
      'id': instance.id,
      'displayName': instance.displayName,
      'isDefault': instance.isDefault,
      'state': _$PluginLifecycleStateEnumMap[instance.state]!,
      'actionHint': ?instance.actionHint,
    };

const _$PluginLifecycleStateEnumMap = {
  PluginLifecycleState.unavailable: 'unavailable',
  PluginLifecycleState.ready: 'ready',
  PluginLifecycleState.degraded: 'degraded',
  PluginLifecycleState.failed: 'failed',
};

_PluginListResponse _$PluginListResponseFromJson(Map json) =>
    _PluginListResponse(
      plugins: (json['plugins'] as List<dynamic>)
          .map(
            (e) => PluginMetadata.fromJson(Map<String, dynamic>.from(e as Map)),
          )
          .toList(),
    );

Map<String, dynamic> _$PluginListResponseToJson(_PluginListResponse instance) =>
    <String, dynamic>{
      'plugins': instance.plugins.map((e) => e.toJson()).toList(),
    };
