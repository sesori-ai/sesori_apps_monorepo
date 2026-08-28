// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'control_message.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ControlTokenRequest _$ControlTokenRequestFromJson(Map json) =>
    ControlTokenRequest(
      id: json['id'] as String,
      forceRefresh: json['forceRefresh'] as bool? ?? false,
      $type: json['type'] as String?,
    );

Map<String, dynamic> _$ControlTokenRequestToJson(
  ControlTokenRequest instance,
) => <String, dynamic>{
  'id': instance.id,
  'forceRefresh': instance.forceRefresh,
  'type': instance.$type,
};

ControlTokenResponse _$ControlTokenResponseFromJson(Map json) =>
    ControlTokenResponse(
      id: json['id'] as String,
      accessToken: json['accessToken'] as String?,
      $type: json['type'] as String?,
    );

Map<String, dynamic> _$ControlTokenResponseToJson(
  ControlTokenResponse instance,
) => <String, dynamic>{
  'id': instance.id,
  'accessToken': ?instance.accessToken,
  'type': instance.$type,
};

ControlStatus _$ControlStatusFromJson(Map json) => ControlStatus(
  relay: $enumDecode(
    _$ControlRelayConnectionStateEnumMap,
    json['relay'],
    unknownValue: ControlRelayConnectionState.unknown,
  ),
  plugin: $enumDecode(
    _$ControlPluginHealthStateEnumMap,
    json['plugin'],
    unknownValue: ControlPluginHealthState.unknown,
  ),
  activeSessionCount: (json['activeSessionCount'] as num?)?.toInt() ?? 0,
  $type: json['type'] as String?,
);

Map<String, dynamic> _$ControlStatusToJson(ControlStatus instance) =>
    <String, dynamic>{
      'relay': _$ControlRelayConnectionStateEnumMap[instance.relay]!,
      'plugin': _$ControlPluginHealthStateEnumMap[instance.plugin]!,
      'activeSessionCount': instance.activeSessionCount,
      'type': instance.$type,
    };

const _$ControlRelayConnectionStateEnumMap = {
  ControlRelayConnectionState.connected: 'connected',
  ControlRelayConnectionState.connecting: 'connecting',
  ControlRelayConnectionState.disconnected: 'disconnected',
  ControlRelayConnectionState.takenOver: 'taken_over',
  ControlRelayConnectionState.unknown: 'unknown',
};

const _$ControlPluginHealthStateEnumMap = {
  ControlPluginHealthState.healthy: 'healthy',
  ControlPluginHealthState.degraded: 'degraded',
  ControlPluginHealthState.unknown: 'unknown',
};

ControlPromptRequest _$ControlPromptRequestFromJson(Map json) =>
    ControlPromptRequest(
      id: json['id'] as String,
      kind: $enumDecode(
        _$ControlPromptKindEnumMap,
        json['kind'],
        unknownValue: ControlPromptKind.unknown,
      ),
      message: json['message'] as String?,
      $type: json['type'] as String?,
    );

Map<String, dynamic> _$ControlPromptRequestToJson(
  ControlPromptRequest instance,
) => <String, dynamic>{
  'id': instance.id,
  'kind': _$ControlPromptKindEnumMap[instance.kind]!,
  'message': ?instance.message,
  'type': instance.$type,
};

const _$ControlPromptKindEnumMap = {
  ControlPromptKind.replaceBridge: 'replace_bridge',
  ControlPromptKind.loginNeeded: 'login_needed',
  ControlPromptKind.unknown: 'unknown',
};

ControlPromptResponse _$ControlPromptResponseFromJson(Map json) =>
    ControlPromptResponse(
      id: json['id'] as String,
      accepted: json['accepted'] as bool,
      $type: json['type'] as String?,
    );

Map<String, dynamic> _$ControlPromptResponseToJson(
  ControlPromptResponse instance,
) => <String, dynamic>{
  'id': instance.id,
  'accepted': instance.accepted,
  'type': instance.$type,
};

ControlShutdown _$ControlShutdownFromJson(Map json) =>
    ControlShutdown($type: json['type'] as String?);

Map<String, dynamic> _$ControlShutdownToJson(ControlShutdown instance) =>
    <String, dynamic>{'type': instance.$type};

ControlUnregisterAndExit _$ControlUnregisterAndExitFromJson(Map json) =>
    ControlUnregisterAndExit($type: json['type'] as String?);

Map<String, dynamic> _$ControlUnregisterAndExitToJson(
  ControlUnregisterAndExit instance,
) => <String, dynamic>{'type': instance.$type};

ControlRegistered _$ControlRegisteredFromJson(Map json) => ControlRegistered(
  bridgeId: json['bridgeId'] as String,
  $type: json['type'] as String?,
);

Map<String, dynamic> _$ControlRegisteredToJson(ControlRegistered instance) =>
    <String, dynamic>{'bridgeId': instance.bridgeId, 'type': instance.$type};
