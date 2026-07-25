// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'plugin_management.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_PluginManagementMetadata _$PluginManagementMetadataFromJson(Map json) =>
    _PluginManagementMetadata(
      setup: PluginSetupMetadata.fromJson(
        Map<String, dynamic>.from(json['setup'] as Map),
      ),
      runtimeState: $enumDecode(
        _$PluginRuntimeStateEnumMap,
        json['runtimeState'],
        unknownValue: PluginRuntimeState.unknown,
      ),
      workState: $enumDecode(
        _$PluginManagementWorkStateEnumMap,
        json['workState'],
        unknownValue: PluginManagementWorkState.unknown,
      ),
      idleTimeoutMins: (json['idleTimeoutMins'] as num).toInt(),
      hasIdleTimeoutOverride: json['hasIdleTimeoutOverride'] as bool,
      actionHint: json['actionHint'] as String?,
    );

Map<String, dynamic> _$PluginManagementMetadataToJson(
  _PluginManagementMetadata instance,
) => <String, dynamic>{
  'setup': instance.setup.toJson(),
  'runtimeState': _$PluginRuntimeStateEnumMap[instance.runtimeState]!,
  'workState': _$PluginManagementWorkStateEnumMap[instance.workState]!,
  'idleTimeoutMins': instance.idleTimeoutMins,
  'hasIdleTimeoutOverride': instance.hasIdleTimeoutOverride,
  'actionHint': ?instance.actionHint,
};

const _$PluginRuntimeStateEnumMap = {
  PluginRuntimeState.disabled: 'disabled',
  PluginRuntimeState.blocked: 'blocked',
  PluginRuntimeState.dormant: 'dormant',
  PluginRuntimeState.starting: 'starting',
  PluginRuntimeState.active: 'active',
  PluginRuntimeState.degraded: 'degraded',
  PluginRuntimeState.stopping: 'stopping',
  PluginRuntimeState.failed: 'failed',
  PluginRuntimeState.unknown: 'unknown',
};

const _$PluginManagementWorkStateEnumMap = {
  PluginManagementWorkState.idle: 'idle',
  PluginManagementWorkState.busy: 'busy',
  PluginManagementWorkState.unknown: 'unknown',
};

_PluginManagementResponse _$PluginManagementResponseFromJson(Map json) =>
    _PluginManagementResponse(
      snapshotToken: json['snapshotToken'] as String?,
      defaultPluginId: json['defaultPluginId'] as String?,
      defaultIdleTimeoutMins: (json['defaultIdleTimeoutMins'] as num).toInt(),
      plugins: (json['plugins'] as List<dynamic>)
          .map(
            (e) => PluginManagementMetadata.fromJson(
              Map<String, dynamic>.from(e as Map),
            ),
          )
          .toList(),
    );

Map<String, dynamic> _$PluginManagementResponseToJson(
  _PluginManagementResponse instance,
) => <String, dynamic>{
  'snapshotToken': ?instance.snapshotToken,
  'defaultPluginId': ?instance.defaultPluginId,
  'defaultIdleTimeoutMins': instance.defaultIdleTimeoutMins,
  'plugins': instance.plugins.map((e) => e.toJson()).toList(),
};

PluginIdleTimeoutApplyAllRequest _$PluginIdleTimeoutApplyAllRequestFromJson(
  Map json,
) => PluginIdleTimeoutApplyAllRequest(
  idleTimeoutMins: _strictIntFromJson(json['idleTimeoutMins'] as num),
  $type: json['type'] as String?,
);

Map<String, dynamic> _$PluginIdleTimeoutApplyAllRequestToJson(
  PluginIdleTimeoutApplyAllRequest instance,
) => <String, dynamic>{
  'idleTimeoutMins': instance.idleTimeoutMins,
  'type': instance.$type,
};

PluginIdleTimeoutSetOverrideRequest
_$PluginIdleTimeoutSetOverrideRequestFromJson(Map json) =>
    PluginIdleTimeoutSetOverrideRequest(
      pluginId: json['pluginId'] as String,
      idleTimeoutMins: _strictIntFromJson(json['idleTimeoutMins'] as num),
      $type: json['type'] as String?,
    );

Map<String, dynamic> _$PluginIdleTimeoutSetOverrideRequestToJson(
  PluginIdleTimeoutSetOverrideRequest instance,
) => <String, dynamic>{
  'pluginId': instance.pluginId,
  'idleTimeoutMins': instance.idleTimeoutMins,
  'type': instance.$type,
};

PluginIdleTimeoutClearOverrideRequest
_$PluginIdleTimeoutClearOverrideRequestFromJson(Map json) =>
    PluginIdleTimeoutClearOverrideRequest(
      pluginId: json['pluginId'] as String,
      $type: json['type'] as String?,
    );

Map<String, dynamic> _$PluginIdleTimeoutClearOverrideRequestToJson(
  PluginIdleTimeoutClearOverrideRequest instance,
) => <String, dynamic>{'pluginId': instance.pluginId, 'type': instance.$type};
