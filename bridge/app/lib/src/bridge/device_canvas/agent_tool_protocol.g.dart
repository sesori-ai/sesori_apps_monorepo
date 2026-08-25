// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'agent_tool_protocol.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_DeviceCanvasAgentToolRendezvous _$DeviceCanvasAgentToolRendezvousFromJson(
  Map json,
) => _DeviceCanvasAgentToolRendezvous(
  protocolVersion: (json['protocolVersion'] as num).toInt(),
  port: (json['port'] as num).toInt(),
);

Map<String, dynamic> _$DeviceCanvasAgentToolRendezvousToJson(
  _DeviceCanvasAgentToolRendezvous instance,
) => <String, dynamic>{
  'protocolVersion': instance.protocolVersion,
  'port': instance.port,
};

_DeviceCanvasAgentToolRegistrationResponse
_$DeviceCanvasAgentToolRegistrationResponseFromJson(Map json) =>
    _DeviceCanvasAgentToolRegistrationResponse(
      bearerToken: json['bearerToken'] as String,
    );

Map<String, dynamic> _$DeviceCanvasAgentToolRegistrationResponseToJson(
  _DeviceCanvasAgentToolRegistrationResponse instance,
) => <String, dynamic>{'bearerToken': instance.bearerToken};

_DeviceCanvasAgentToolListRequest _$DeviceCanvasAgentToolListRequestFromJson(
  Map json,
) => _DeviceCanvasAgentToolListRequest(
  backendSessionId: json['backendSessionId'] as String,
);

Map<String, dynamic> _$DeviceCanvasAgentToolListRequestToJson(
  _DeviceCanvasAgentToolListRequest instance,
) => <String, dynamic>{'backendSessionId': instance.backendSessionId};

_DeviceCanvasAgentToolMutationRequest
_$DeviceCanvasAgentToolMutationRequestFromJson(Map json) =>
    _DeviceCanvasAgentToolMutationRequest(
      backendSessionId: json['backendSessionId'] as String,
      deviceKey: json['deviceKey'] as String,
    );

Map<String, dynamic> _$DeviceCanvasAgentToolMutationRequestToJson(
  _DeviceCanvasAgentToolMutationRequest instance,
) => <String, dynamic>{
  'backendSessionId': instance.backendSessionId,
  'deviceKey': instance.deviceKey,
};

_DeviceCanvasAgentToolDevice _$DeviceCanvasAgentToolDeviceFromJson(Map json) =>
    _DeviceCanvasAgentToolDevice(
      deviceKey: json['deviceKey'] as String,
      platform: json['platform'] as String,
      displayName: json['displayName'] as String,
      runtimeDescription: json['runtimeDescription'] as String,
      modelDescription: json['modelDescription'] as String,
      ownership: $enumDecode(
        _$DeviceCanvasAgentToolDeviceOwnershipEnumMap,
        json['ownership'],
      ),
    );

Map<String, dynamic> _$DeviceCanvasAgentToolDeviceToJson(
  _DeviceCanvasAgentToolDevice instance,
) => <String, dynamic>{
  'deviceKey': instance.deviceKey,
  'platform': instance.platform,
  'displayName': instance.displayName,
  'runtimeDescription': instance.runtimeDescription,
  'modelDescription': instance.modelDescription,
  'ownership':
      _$DeviceCanvasAgentToolDeviceOwnershipEnumMap[instance.ownership]!,
};

const _$DeviceCanvasAgentToolDeviceOwnershipEnumMap = {
  DeviceCanvasAgentToolDeviceOwnership.unclaimed: 'unclaimed',
  DeviceCanvasAgentToolDeviceOwnership.currentSession: 'currentSession',
  DeviceCanvasAgentToolDeviceOwnership.anotherSession: 'anotherSession',
};

DeviceCanvasAgentToolListedResponse
_$DeviceCanvasAgentToolListedResponseFromJson(Map json) =>
    DeviceCanvasAgentToolListedResponse(
      devices: (json['devices'] as List<dynamic>)
          .map(
            (e) => DeviceCanvasAgentToolDevice.fromJson(
              Map<String, dynamic>.from(e as Map),
            ),
          )
          .toList(),
      truncated: json['truncated'] as bool,
      $type: json['outcome'] as String?,
    );

Map<String, dynamic> _$DeviceCanvasAgentToolListedResponseToJson(
  DeviceCanvasAgentToolListedResponse instance,
) => <String, dynamic>{
  'devices': instance.devices.map((e) => e.toJson()).toList(),
  'truncated': instance.truncated,
  'outcome': instance.$type,
};

DeviceCanvasAgentToolClaimedResponse
_$DeviceCanvasAgentToolClaimedResponseFromJson(Map json) =>
    DeviceCanvasAgentToolClaimedResponse(
      deviceKey: json['deviceKey'] as String,
      $type: json['outcome'] as String?,
    );

Map<String, dynamic> _$DeviceCanvasAgentToolClaimedResponseToJson(
  DeviceCanvasAgentToolClaimedResponse instance,
) => <String, dynamic>{
  'deviceKey': instance.deviceKey,
  'outcome': instance.$type,
};

DeviceCanvasAgentToolAlreadyOwnedResponse
_$DeviceCanvasAgentToolAlreadyOwnedResponseFromJson(Map json) =>
    DeviceCanvasAgentToolAlreadyOwnedResponse(
      deviceKey: json['deviceKey'] as String,
      $type: json['outcome'] as String?,
    );

Map<String, dynamic> _$DeviceCanvasAgentToolAlreadyOwnedResponseToJson(
  DeviceCanvasAgentToolAlreadyOwnedResponse instance,
) => <String, dynamic>{
  'deviceKey': instance.deviceKey,
  'outcome': instance.$type,
};

DeviceCanvasAgentToolReleasedResponse
_$DeviceCanvasAgentToolReleasedResponseFromJson(Map json) =>
    DeviceCanvasAgentToolReleasedResponse(
      deviceKey: json['deviceKey'] as String,
      $type: json['outcome'] as String?,
    );

Map<String, dynamic> _$DeviceCanvasAgentToolReleasedResponseToJson(
  DeviceCanvasAgentToolReleasedResponse instance,
) => <String, dynamic>{
  'deviceKey': instance.deviceKey,
  'outcome': instance.$type,
};

DeviceCanvasAgentToolAlreadyReleasedResponse
_$DeviceCanvasAgentToolAlreadyReleasedResponseFromJson(Map json) =>
    DeviceCanvasAgentToolAlreadyReleasedResponse(
      deviceKey: json['deviceKey'] as String,
      $type: json['outcome'] as String?,
    );

Map<String, dynamic> _$DeviceCanvasAgentToolAlreadyReleasedResponseToJson(
  DeviceCanvasAgentToolAlreadyReleasedResponse instance,
) => <String, dynamic>{
  'deviceKey': instance.deviceKey,
  'outcome': instance.$type,
};

DeviceCanvasAgentToolConflictResponse
_$DeviceCanvasAgentToolConflictResponseFromJson(Map json) =>
    DeviceCanvasAgentToolConflictResponse(
      deviceKey: json['deviceKey'] as String,
      $type: json['outcome'] as String?,
    );

Map<String, dynamic> _$DeviceCanvasAgentToolConflictResponseToJson(
  DeviceCanvasAgentToolConflictResponse instance,
) => <String, dynamic>{
  'deviceKey': instance.deviceKey,
  'outcome': instance.$type,
};

DeviceCanvasAgentToolDeviceUnavailableResponse
_$DeviceCanvasAgentToolDeviceUnavailableResponseFromJson(Map json) =>
    DeviceCanvasAgentToolDeviceUnavailableResponse(
      deviceKey: json['deviceKey'] as String,
      $type: json['outcome'] as String?,
    );

Map<String, dynamic> _$DeviceCanvasAgentToolDeviceUnavailableResponseToJson(
  DeviceCanvasAgentToolDeviceUnavailableResponse instance,
) => <String, dynamic>{
  'deviceKey': instance.deviceKey,
  'outcome': instance.$type,
};

DeviceCanvasAgentToolSessionUnavailableResponse
_$DeviceCanvasAgentToolSessionUnavailableResponseFromJson(Map json) =>
    DeviceCanvasAgentToolSessionUnavailableResponse(
      $type: json['outcome'] as String?,
    );

Map<String, dynamic> _$DeviceCanvasAgentToolSessionUnavailableResponseToJson(
  DeviceCanvasAgentToolSessionUnavailableResponse instance,
) => <String, dynamic>{'outcome': instance.$type};

DeviceCanvasAgentToolIntegrationUnavailableResponse
_$DeviceCanvasAgentToolIntegrationUnavailableResponseFromJson(Map json) =>
    DeviceCanvasAgentToolIntegrationUnavailableResponse(
      $type: json['outcome'] as String?,
    );

Map<String, dynamic>
_$DeviceCanvasAgentToolIntegrationUnavailableResponseToJson(
  DeviceCanvasAgentToolIntegrationUnavailableResponse instance,
) => <String, dynamic>{'outcome': instance.$type};

DeviceCanvasAgentToolBridgeUnavailableResponse
_$DeviceCanvasAgentToolBridgeUnavailableResponseFromJson(Map json) =>
    DeviceCanvasAgentToolBridgeUnavailableResponse(
      $type: json['outcome'] as String?,
    );

Map<String, dynamic> _$DeviceCanvasAgentToolBridgeUnavailableResponseToJson(
  DeviceCanvasAgentToolBridgeUnavailableResponse instance,
) => <String, dynamic>{'outcome': instance.$type};

DeviceCanvasAgentToolInvalidRequestResponse
_$DeviceCanvasAgentToolInvalidRequestResponseFromJson(Map json) =>
    DeviceCanvasAgentToolInvalidRequestResponse(
      $type: json['outcome'] as String?,
    );

Map<String, dynamic> _$DeviceCanvasAgentToolInvalidRequestResponseToJson(
  DeviceCanvasAgentToolInvalidRequestResponse instance,
) => <String, dynamic>{'outcome': instance.$type};

DeviceCanvasAgentToolInternalErrorResponse
_$DeviceCanvasAgentToolInternalErrorResponseFromJson(Map json) =>
    DeviceCanvasAgentToolInternalErrorResponse(
      $type: json['outcome'] as String?,
    );

Map<String, dynamic> _$DeviceCanvasAgentToolInternalErrorResponseToJson(
  DeviceCanvasAgentToolInternalErrorResponse instance,
) => <String, dynamic>{'outcome': instance.$type};
