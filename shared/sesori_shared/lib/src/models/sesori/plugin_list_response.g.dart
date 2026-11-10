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
  failureBlock: $enumDecodeNullable(
    _$PluginFailureBlockEnumMap,
    json['failureBlock'],
    unknownValue: PluginFailureBlock.unknown,
  ),
  supportsPromptAttachments:
      json['supportsPromptAttachments'] as bool? ?? false,
  mcpScopes: (json['mcpScopes'] as List<dynamic>?)
      ?.map(
        (e) => $enumDecode(
          _$McpScopeKindEnumMap,
          e,
          unknownValue: McpScopeKind.unknown,
        ),
      )
      .toSet(),
);

Map<String, dynamic> _$PluginMetadataToJson(_PluginMetadata instance) =>
    <String, dynamic>{
      'id': instance.id,
      'displayName': instance.displayName,
      'isDefault': instance.isDefault,
      'state': _$PluginLifecycleStateEnumMap[instance.state]!,
      'actionHint': ?instance.actionHint,
      'failureBlock': ?_$PluginFailureBlockEnumMap[instance.failureBlock],
      'supportsPromptAttachments': instance.supportsPromptAttachments,
      'mcpScopes': ?instance.mcpScopes
          ?.map((e) => _$McpScopeKindEnumMap[e]!)
          .toList(),
    };

const _$PluginLifecycleStateEnumMap = {
  PluginLifecycleState.unavailable: 'unavailable',
  PluginLifecycleState.ready: 'ready',
  PluginLifecycleState.degraded: 'degraded',
  PluginLifecycleState.failed: 'failed',
};

const _$PluginFailureBlockEnumMap = {
  PluginFailureBlock.authenticationRequired: 'authenticationRequired',
  PluginFailureBlock.unavailable: 'unavailable',
  PluginFailureBlock.unknown: 'unknown',
};

const _$McpScopeKindEnumMap = {
  McpScopeKind.harness: 'harness',
  McpScopeKind.project: 'project',
  McpScopeKind.session: 'session',
  McpScopeKind.unknown: 'unknown',
};

_PluginListResponse _$PluginListResponseFromJson(Map json) =>
    _PluginListResponse(
      plugins: (json['plugins'] as List<dynamic>)
          .map(
            (e) => PluginMetadata.fromJson(Map<String, dynamic>.from(e as Map)),
          )
          .toList(),
      bridgeId: json['bridgeId'] as String?,
      supportsSessionOptions: json['supportsSessionOptions'] as bool? ?? false,
      supportsFileUploads: json['supportsFileUploads'] as bool? ?? false,
    );

Map<String, dynamic> _$PluginListResponseToJson(_PluginListResponse instance) =>
    <String, dynamic>{
      'plugins': instance.plugins.map((e) => e.toJson()).toList(),
      'bridgeId': ?instance.bridgeId,
      'supportsSessionOptions': instance.supportsSessionOptions,
      'supportsFileUploads': instance.supportsFileUploads,
    };
