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
      authenticationState:
          $enumDecodeNullable(
            _$PluginAuthenticationStateEnumMap,
            json['authenticationState'],
            unknownValue: PluginAuthenticationState.unknown,
          ) ??
          PluginAuthenticationState.idle,
      idleTimeoutMins: (json['idleTimeoutMins'] as num).toInt(),
      hasIdleTimeoutOverride: json['hasIdleTimeoutOverride'] as bool,
      managementCapabilities: (json['managementCapabilities'] as List<dynamic>)
          .map(
            (e) => $enumDecode(
              _$PluginManagementCapabilityEnumMap,
              e,
              unknownValue: PluginManagementCapability.unknown,
            ),
          )
          .toSet(),
      actionHint: json['actionHint'] as String?,
    );

Map<String, dynamic> _$PluginManagementMetadataToJson(
  _PluginManagementMetadata instance,
) => <String, dynamic>{
  'setup': instance.setup.toJson(),
  'runtimeState': _$PluginRuntimeStateEnumMap[instance.runtimeState]!,
  'workState': _$PluginManagementWorkStateEnumMap[instance.workState]!,
  'authenticationState':
      _$PluginAuthenticationStateEnumMap[instance.authenticationState]!,
  'idleTimeoutMins': instance.idleTimeoutMins,
  'hasIdleTimeoutOverride': instance.hasIdleTimeoutOverride,
  'managementCapabilities': instance.managementCapabilities
      .map((e) => _$PluginManagementCapabilityEnumMap[e]!)
      .toList(),
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

const _$PluginAuthenticationStateEnumMap = {
  PluginAuthenticationState.idle: 'idle',
  PluginAuthenticationState.inProgress: 'inProgress',
  PluginAuthenticationState.unknown: 'unknown',
};

const _$PluginManagementCapabilityEnumMap = {
  PluginManagementCapability.lifecycle: 'lifecycle',
  PluginManagementCapability.setupRefresh: 'setupRefresh',
  PluginManagementCapability.idleTimeout: 'idleTimeout',
  PluginManagementCapability.install: 'install',
  PluginManagementCapability.authentication: 'authentication',
  PluginManagementCapability.unknown: 'unknown',
};

PluginAuthenticationDeviceCodeChallengeResponse
_$PluginAuthenticationDeviceCodeChallengeResponseFromJson(Map json) =>
    PluginAuthenticationDeviceCodeChallengeResponse(
      verificationUrl: json['verificationUrl'] as String,
      userCode: json['userCode'] as String,
      $type: json['type'] as String?,
    );

Map<String, dynamic> _$PluginAuthenticationDeviceCodeChallengeResponseToJson(
  PluginAuthenticationDeviceCodeChallengeResponse instance,
) => <String, dynamic>{
  'verificationUrl': instance.verificationUrl,
  'userCode': instance.userCode,
  'type': instance.$type,
};

PluginAuthenticationBrowserChallengeResponse
_$PluginAuthenticationBrowserChallengeResponseFromJson(Map json) =>
    PluginAuthenticationBrowserChallengeResponse(
      authorizationUrl: json['authorizationUrl'] as String,
      expectedCallbackUrl: json['expectedCallbackUrl'] as String,
      $type: json['type'] as String?,
    );

Map<String, dynamic> _$PluginAuthenticationBrowserChallengeResponseToJson(
  PluginAuthenticationBrowserChallengeResponse instance,
) => <String, dynamic>{
  'authorizationUrl': instance.authorizationUrl,
  'expectedCallbackUrl': instance.expectedCallbackUrl,
  'type': instance.$type,
};

PluginAuthenticationUnknownChallengeResponse
_$PluginAuthenticationUnknownChallengeResponseFromJson(Map json) =>
    PluginAuthenticationUnknownChallengeResponse(
      $type: json['type'] as String?,
    );

Map<String, dynamic> _$PluginAuthenticationUnknownChallengeResponseToJson(
  PluginAuthenticationUnknownChallengeResponse instance,
) => <String, dynamic>{'type': instance.$type};

_PluginAuthenticationRedirectRequest
_$PluginAuthenticationRedirectRequestFromJson(Map json) =>
    _PluginAuthenticationRedirectRequest(
      redirectUrl: json['redirectUrl'] as String,
    );

Map<String, dynamic> _$PluginAuthenticationRedirectRequestToJson(
  _PluginAuthenticationRedirectRequest instance,
) => <String, dynamic>{'redirectUrl': instance.redirectUrl};

PluginAuthenticationCompletedProgress
_$PluginAuthenticationCompletedProgressFromJson(Map json) =>
    PluginAuthenticationCompletedProgress($type: json['type'] as String?);

Map<String, dynamic> _$PluginAuthenticationCompletedProgressToJson(
  PluginAuthenticationCompletedProgress instance,
) => <String, dynamic>{'type': instance.$type};

PluginAuthenticationFailedProgress _$PluginAuthenticationFailedProgressFromJson(
  Map json,
) => PluginAuthenticationFailedProgress(
  message: json['message'] as String,
  $type: json['type'] as String?,
);

Map<String, dynamic> _$PluginAuthenticationFailedProgressToJson(
  PluginAuthenticationFailedProgress instance,
) => <String, dynamic>{'message': instance.message, 'type': instance.$type};

PluginAuthenticationCancelledProgress
_$PluginAuthenticationCancelledProgressFromJson(Map json) =>
    PluginAuthenticationCancelledProgress($type: json['type'] as String?);

Map<String, dynamic> _$PluginAuthenticationCancelledProgressToJson(
  PluginAuthenticationCancelledProgress instance,
) => <String, dynamic>{'type': instance.$type};

PluginAuthenticationUnknownProgress
_$PluginAuthenticationUnknownProgressFromJson(Map json) =>
    PluginAuthenticationUnknownProgress($type: json['type'] as String?);

Map<String, dynamic> _$PluginAuthenticationUnknownProgressToJson(
  PluginAuthenticationUnknownProgress instance,
) => <String, dynamic>{'type': instance.$type};

_PluginManagementResponse _$PluginManagementResponseFromJson(Map json) =>
    _PluginManagementResponse(
      snapshotToken: json['snapshotToken'] as String,
      bridgeId: json['bridgeId'] as String,
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
  'snapshotToken': instance.snapshotToken,
  'bridgeId': instance.bridgeId,
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

PluginLifecycleInstallRequest _$PluginLifecycleInstallRequestFromJson(
  Map json,
) => PluginLifecycleInstallRequest($type: json['type'] as String?);

Map<String, dynamic> _$PluginLifecycleInstallRequestToJson(
  PluginLifecycleInstallRequest instance,
) => <String, dynamic>{'type': instance.$type};

PluginIdleTimeoutApplyAllRequest _$PluginIdleTimeoutApplyAllRequestFromJson(
  Map json,
) => PluginIdleTimeoutApplyAllRequest(
  idleTimeoutMins: strictIntJsonConverter.fromJson(json['idleTimeoutMins']),
  $type: json['type'] as String?,
);

Map<String, dynamic> _$PluginIdleTimeoutApplyAllRequestToJson(
  PluginIdleTimeoutApplyAllRequest instance,
) => <String, dynamic>{
  'idleTimeoutMins': ?strictIntJsonConverter.toJson(instance.idleTimeoutMins),
  'type': instance.$type,
};

PluginIdleTimeoutSetOverrideRequest
_$PluginIdleTimeoutSetOverrideRequestFromJson(Map json) =>
    PluginIdleTimeoutSetOverrideRequest(
      pluginId: json['pluginId'] as String,
      idleTimeoutMins: strictIntJsonConverter.fromJson(json['idleTimeoutMins']),
      $type: json['type'] as String?,
    );

Map<String, dynamic> _$PluginIdleTimeoutSetOverrideRequestToJson(
  PluginIdleTimeoutSetOverrideRequest instance,
) => <String, dynamic>{
  'pluginId': instance.pluginId,
  'idleTimeoutMins': ?strictIntJsonConverter.toJson(instance.idleTimeoutMins),
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
          .map(
            (e) => $enumDecode(
              _$PluginLifecycleConflictReasonEnumMap,
              e,
              unknownValue: PluginLifecycleConflictReason.unknown,
            ),
          )
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
  PluginLifecycleConflictReason.unsupported: 'unsupported',
  PluginLifecycleConflictReason.unknown: 'unknown',
};

_PluginAuthenticationConflict _$PluginAuthenticationConflictFromJson(
  Map json,
) => _PluginAuthenticationConflict(
  pluginId: json['pluginId'] as String,
  reasons: (json['reasons'] as List<dynamic>)
      .map(
        (e) => $enumDecode(
          _$PluginAuthenticationConflictReasonEnumMap,
          e,
          unknownValue: PluginAuthenticationConflictReason.unknown,
        ),
      )
      .toList(),
  current: PluginManagementMetadata.fromJson(
    Map<String, dynamic>.from(json['current'] as Map),
  ),
);

Map<String, dynamic> _$PluginAuthenticationConflictToJson(
  _PluginAuthenticationConflict instance,
) => <String, dynamic>{
  'pluginId': instance.pluginId,
  'reasons': instance.reasons
      .map((e) => _$PluginAuthenticationConflictReasonEnumMap[e]!)
      .toList(),
  'current': instance.current.toJson(),
};

const _$PluginAuthenticationConflictReasonEnumMap = {
  PluginAuthenticationConflictReason.inFlight: 'inFlight',
  PluginAuthenticationConflictReason.setupNotRequired: 'setupNotRequired',
  PluginAuthenticationConflictReason.unsupported: 'unsupported',
  PluginAuthenticationConflictReason.noActive: 'noActive',
  PluginAuthenticationConflictReason.wrongKind: 'wrongKind',
  PluginAuthenticationConflictReason.alreadySubmitted: 'alreadySubmitted',
  PluginAuthenticationConflictReason.unknown: 'unknown',
};
