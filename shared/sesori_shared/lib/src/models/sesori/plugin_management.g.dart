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
      revision: (json['revision'] as num).toInt(),
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
  'revision': instance.revision,
  'defaultPluginId': ?instance.defaultPluginId,
  'defaultIdleTimeoutMins': instance.defaultIdleTimeoutMins,
  'plugins': instance.plugins.map((e) => e.toJson()).toList(),
};

PluginLifecycleEnableRequest _$PluginLifecycleEnableRequestFromJson(Map json) =>
    PluginLifecycleEnableRequest($type: json['type'] as String?);

Map<String, dynamic> _$PluginLifecycleEnableRequestToJson(
  PluginLifecycleEnableRequest instance,
) => <String, dynamic>{'type': instance.$type};

PluginLifecycleDisableRequest _$PluginLifecycleDisableRequestFromJson(
  Map json,
) => PluginLifecycleDisableRequest(
  mode: $enumDecode(_$PluginStopModeEnumMap, json['mode']),
  $type: json['type'] as String?,
);

Map<String, dynamic> _$PluginLifecycleDisableRequestToJson(
  PluginLifecycleDisableRequest instance,
) => <String, dynamic>{
  'mode': _$PluginStopModeEnumMap[instance.mode]!,
  'type': instance.$type,
};

const _$PluginStopModeEnumMap = {
  PluginStopMode.safe: 'safe',
  PluginStopMode.force: 'force',
};

PluginLifecycleRestartRequest _$PluginLifecycleRestartRequestFromJson(
  Map json,
) => PluginLifecycleRestartRequest(
  mode: $enumDecode(_$PluginStopModeEnumMap, json['mode']),
  $type: json['type'] as String?,
);

Map<String, dynamic> _$PluginLifecycleRestartRequestToJson(
  PluginLifecycleRestartRequest instance,
) => <String, dynamic>{
  'mode': _$PluginStopModeEnumMap[instance.mode]!,
  'type': instance.$type,
};

PluginLifecycleRefreshRequest _$PluginLifecycleRefreshRequestFromJson(
  Map json,
) => PluginLifecycleRefreshRequest($type: json['type'] as String?);

Map<String, dynamic> _$PluginLifecycleRefreshRequestToJson(
  PluginLifecycleRefreshRequest instance,
) => <String, dynamic>{'type': instance.$type};

PluginIdleTimeoutApplyAllRequest _$PluginIdleTimeoutApplyAllRequestFromJson(
  Map json,
) => PluginIdleTimeoutApplyAllRequest(
  idleTimeoutMins: _strictIntFromJson(json['idleTimeoutMins']),
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
      idleTimeoutMins: _strictIntFromJson(json['idleTimeoutMins']),
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

_PluginLifecycleConflict _$PluginLifecycleConflictFromJson(Map json) =>
    _PluginLifecycleConflict(
      pluginId: json['pluginId'] as String,
      reasons: (json['reasons'] as List<dynamic>)
          .map((e) => $enumDecode(_$PluginLifecycleConflictReasonEnumMap, e))
          .toList(),
      current: PluginManagementMetadata.fromJson(
        Map<String, dynamic>.from(json['current'] as Map),
      ),
    );

Map<String, dynamic> _$PluginLifecycleConflictToJson(
  _PluginLifecycleConflict instance,
) => <String, dynamic>{
  'pluginId': instance.pluginId,
  'reasons': instance.reasons
      .map((e) => _$PluginLifecycleConflictReasonEnumMap[e]!)
      .toList(),
  'current': instance.current.toJson(),
};

const _$PluginLifecycleConflictReasonEnumMap = {
  PluginLifecycleConflictReason.inFlight: 'inFlight',
  PluginLifecycleConflictReason.busy: 'busy',
  PluginLifecycleConflictReason.workStateUnknown: 'workStateUnknown',
  PluginLifecycleConflictReason.transitioning: 'transitioning',
  PluginLifecycleConflictReason.notEnabled: 'notEnabled',
};
