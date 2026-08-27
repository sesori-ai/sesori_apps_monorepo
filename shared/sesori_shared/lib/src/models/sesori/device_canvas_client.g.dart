// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'device_canvas_client.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_DeviceCanvasRtcDescription _$DeviceCanvasRtcDescriptionFromJson(Map json) =>
    _DeviceCanvasRtcDescription(
      type: $enumDecode(
        _$DeviceCanvasRtcDescriptionTypeEnumMap,
        json['type'],
        unknownValue: DeviceCanvasRtcDescriptionType.unknown,
      ),
      sdp: json['sdp'] as String,
      fingerprint: json['fingerprint'] as String,
    );

Map<String, dynamic> _$DeviceCanvasRtcDescriptionToJson(
  _DeviceCanvasRtcDescription instance,
) => <String, dynamic>{
  'type': _$DeviceCanvasRtcDescriptionTypeEnumMap[instance.type]!,
  'sdp': instance.sdp,
  'fingerprint': instance.fingerprint,
};

const _$DeviceCanvasRtcDescriptionTypeEnumMap = {
  DeviceCanvasRtcDescriptionType.offer: 'offer',
  DeviceCanvasRtcDescriptionType.answer: 'answer',
  DeviceCanvasRtcDescriptionType.unknown: 'unknown',
};

_DeviceCanvasIceCandidate _$DeviceCanvasIceCandidateFromJson(Map json) =>
    _DeviceCanvasIceCandidate(
      candidate: json['candidate'] as String,
      sdpMid: json['sdpMid'] as String,
      sdpMLineIndex: (json['sdpMLineIndex'] as num).toInt(),
    );

Map<String, dynamic> _$DeviceCanvasIceCandidateToJson(
  _DeviceCanvasIceCandidate instance,
) => <String, dynamic>{
  'candidate': instance.candidate,
  'sdpMid': instance.sdpMid,
  'sdpMLineIndex': instance.sdpMLineIndex,
};

_DeviceCanvasTurnCredentialsRequest
_$DeviceCanvasTurnCredentialsRequestFromJson(Map json) =>
    _DeviceCanvasTurnCredentialsRequest(
      bridgeId: json['bridgeId'] as String,
      operationId: json['operationId'] as String,
      leaseExpiresAt: (json['leaseExpiresAt'] as num).toInt(),
    );

Map<String, dynamic> _$DeviceCanvasTurnCredentialsRequestToJson(
  _DeviceCanvasTurnCredentialsRequest instance,
) => <String, dynamic>{
  'bridgeId': instance.bridgeId,
  'operationId': instance.operationId,
  'leaseExpiresAt': instance.leaseExpiresAt,
};

_DeviceCanvasTurnConfiguration _$DeviceCanvasTurnConfigurationFromJson(
  Map json,
) => _DeviceCanvasTurnConfiguration(
  urls: (json['urls'] as List<dynamic>).map((e) => e as String).toList(),
  username: json['username'] as String,
  credential: json['credential'] as String,
  expiresAt: (json['expiresAt'] as num).toInt(),
);

Map<String, dynamic> _$DeviceCanvasTurnConfigurationToJson(
  _DeviceCanvasTurnConfiguration instance,
) => <String, dynamic>{
  'urls': instance.urls,
  'username': instance.username,
  'credential': instance.credential,
  'expiresAt': instance.expiresAt,
};

_DeviceCanvasStreamPrepareRequest _$DeviceCanvasStreamPrepareRequestFromJson(
  Map json,
) => _DeviceCanvasStreamPrepareRequest(
  expectedBridgeId: json['expectedBridgeId'] as String,
  sessionId: json['sessionId'] as String,
  deviceKey: json['deviceKey'] as String,
  expectedClaimRevision: (json['expectedClaimRevision'] as num).toInt(),
  operationId: json['operationId'] as String,
  leaseId: json['leaseId'] as String,
  control: json['control'] as bool,
);

Map<String, dynamic> _$DeviceCanvasStreamPrepareRequestToJson(
  _DeviceCanvasStreamPrepareRequest instance,
) => <String, dynamic>{
  'expectedBridgeId': instance.expectedBridgeId,
  'sessionId': instance.sessionId,
  'deviceKey': instance.deviceKey,
  'expectedClaimRevision': instance.expectedClaimRevision,
  'operationId': instance.operationId,
  'leaseId': instance.leaseId,
  'control': instance.control,
};

_DeviceCanvasStreamPrepareResponse _$DeviceCanvasStreamPrepareResponseFromJson(
  Map json,
) => _DeviceCanvasStreamPrepareResponse(
  outcome: $enumDecode(
    _$DeviceCanvasStreamPrepareOutcomeEnumMap,
    json['outcome'],
    unknownValue: DeviceCanvasStreamPrepareOutcome.unknown,
  ),
  leaseId: json['leaseId'] as String?,
  expiresAt: (json['expiresAt'] as num?)?.toInt(),
  turn: json['turn'] == null
      ? null
      : DeviceCanvasTurnConfiguration.fromJson(
          Map<String, dynamic>.from(json['turn'] as Map),
        ),
);

Map<String, dynamic> _$DeviceCanvasStreamPrepareResponseToJson(
  _DeviceCanvasStreamPrepareResponse instance,
) => <String, dynamic>{
  'outcome': _$DeviceCanvasStreamPrepareOutcomeEnumMap[instance.outcome]!,
  'leaseId': ?instance.leaseId,
  'expiresAt': ?instance.expiresAt,
  'turn': ?instance.turn?.toJson(),
};

const _$DeviceCanvasStreamPrepareOutcomeEnumMap = {
  DeviceCanvasStreamPrepareOutcome.prepared: 'prepared',
  DeviceCanvasStreamPrepareOutcome.controllerConflict: 'controllerConflict',
  DeviceCanvasStreamPrepareOutcome.unavailable: 'unavailable',
  DeviceCanvasStreamPrepareOutcome.unauthorized: 'unauthorized',
  DeviceCanvasStreamPrepareOutcome.unsupported: 'unsupported',
  DeviceCanvasStreamPrepareOutcome.unknown: 'unknown',
};

_DeviceCanvasStreamStartRequest _$DeviceCanvasStreamStartRequestFromJson(
  Map json,
) => _DeviceCanvasStreamStartRequest(
  expectedBridgeId: json['expectedBridgeId'] as String,
  sessionId: json['sessionId'] as String,
  deviceKey: json['deviceKey'] as String,
  expectedClaimRevision: (json['expectedClaimRevision'] as num).toInt(),
  operationId: json['operationId'] as String,
  leaseId: json['leaseId'] as String?,
  control: json['control'] as bool,
  offer: DeviceCanvasRtcDescription.fromJson(
    Map<String, dynamic>.from(json['offer'] as Map),
  ),
  iceCandidates:
      (json['iceCandidates'] as List<dynamic>?)
          ?.map(
            (e) => DeviceCanvasIceCandidate.fromJson(
              Map<String, dynamic>.from(e as Map),
            ),
          )
          .toList() ??
      const <DeviceCanvasIceCandidate>[],
);

Map<String, dynamic> _$DeviceCanvasStreamStartRequestToJson(
  _DeviceCanvasStreamStartRequest instance,
) => <String, dynamic>{
  'expectedBridgeId': instance.expectedBridgeId,
  'sessionId': instance.sessionId,
  'deviceKey': instance.deviceKey,
  'expectedClaimRevision': instance.expectedClaimRevision,
  'operationId': instance.operationId,
  'leaseId': ?instance.leaseId,
  'control': instance.control,
  'offer': instance.offer.toJson(),
  'iceCandidates': instance.iceCandidates.map((e) => e.toJson()).toList(),
};

_DeviceCanvasStreamStartResponse _$DeviceCanvasStreamStartResponseFromJson(
  Map json,
) => _DeviceCanvasStreamStartResponse(
  outcome: $enumDecode(
    _$DeviceCanvasStreamStartOutcomeEnumMap,
    json['outcome'],
    unknownValue: DeviceCanvasStreamStartOutcome.unknown,
  ),
  leaseId: json['leaseId'] as String?,
  expiresAt: (json['expiresAt'] as num?)?.toInt(),
  answer: json['answer'] == null
      ? null
      : DeviceCanvasRtcDescription.fromJson(
          Map<String, dynamic>.from(json['answer'] as Map),
        ),
  iceCandidates:
      (json['iceCandidates'] as List<dynamic>?)
          ?.map(
            (e) => DeviceCanvasIceCandidate.fromJson(
              Map<String, dynamic>.from(e as Map),
            ),
          )
          .toList() ??
      const <DeviceCanvasIceCandidate>[],
  turn: json['turn'] == null
      ? null
      : DeviceCanvasTurnConfiguration.fromJson(
          Map<String, dynamic>.from(json['turn'] as Map),
        ),
);

Map<String, dynamic> _$DeviceCanvasStreamStartResponseToJson(
  _DeviceCanvasStreamStartResponse instance,
) => <String, dynamic>{
  'outcome': _$DeviceCanvasStreamStartOutcomeEnumMap[instance.outcome]!,
  'leaseId': ?instance.leaseId,
  'expiresAt': ?instance.expiresAt,
  'answer': ?instance.answer?.toJson(),
  'iceCandidates': instance.iceCandidates.map((e) => e.toJson()).toList(),
  'turn': ?instance.turn?.toJson(),
};

const _$DeviceCanvasStreamStartOutcomeEnumMap = {
  DeviceCanvasStreamStartOutcome.started: 'started',
  DeviceCanvasStreamStartOutcome.controllerConflict: 'controllerConflict',
  DeviceCanvasStreamStartOutcome.unavailable: 'unavailable',
  DeviceCanvasStreamStartOutcome.unauthorized: 'unauthorized',
  DeviceCanvasStreamStartOutcome.unsupported: 'unsupported',
  DeviceCanvasStreamStartOutcome.unknown: 'unknown',
};

_DeviceCanvasStreamStatusRequest _$DeviceCanvasStreamStatusRequestFromJson(
  Map json,
) => _DeviceCanvasStreamStatusRequest(
  expectedBridgeId: json['expectedBridgeId'] as String,
  sessionId: json['sessionId'] as String,
  deviceKey: json['deviceKey'] as String,
  expectedClaimRevision: (json['expectedClaimRevision'] as num).toInt(),
  operationId: json['operationId'] as String,
);

Map<String, dynamic> _$DeviceCanvasStreamStatusRequestToJson(
  _DeviceCanvasStreamStatusRequest instance,
) => <String, dynamic>{
  'expectedBridgeId': instance.expectedBridgeId,
  'sessionId': instance.sessionId,
  'deviceKey': instance.deviceKey,
  'expectedClaimRevision': instance.expectedClaimRevision,
  'operationId': instance.operationId,
};

_DeviceCanvasStreamStatusResponse _$DeviceCanvasStreamStatusResponseFromJson(
  Map json,
) => _DeviceCanvasStreamStatusResponse(
  outcome: $enumDecode(
    _$DeviceCanvasStreamStatusOutcomeEnumMap,
    json['outcome'],
    unknownValue: DeviceCanvasStreamStatusOutcome.unknown,
  ),
  leaseId: json['leaseId'] as String?,
  expiresAt: (json['expiresAt'] as num?)?.toInt(),
  answer: json['answer'] == null
      ? null
      : DeviceCanvasRtcDescription.fromJson(
          Map<String, dynamic>.from(json['answer'] as Map),
        ),
  iceCandidates:
      (json['iceCandidates'] as List<dynamic>?)
          ?.map(
            (e) => DeviceCanvasIceCandidate.fromJson(
              Map<String, dynamic>.from(e as Map),
            ),
          )
          .toList() ??
      const <DeviceCanvasIceCandidate>[],
  turn: json['turn'] == null
      ? null
      : DeviceCanvasTurnConfiguration.fromJson(
          Map<String, dynamic>.from(json['turn'] as Map),
        ),
  offerFingerprint: json['offerFingerprint'] as String?,
);

Map<String, dynamic> _$DeviceCanvasStreamStatusResponseToJson(
  _DeviceCanvasStreamStatusResponse instance,
) => <String, dynamic>{
  'outcome': _$DeviceCanvasStreamStatusOutcomeEnumMap[instance.outcome]!,
  'leaseId': ?instance.leaseId,
  'expiresAt': ?instance.expiresAt,
  'answer': ?instance.answer?.toJson(),
  'iceCandidates': instance.iceCandidates.map((e) => e.toJson()).toList(),
  'turn': ?instance.turn?.toJson(),
  'offerFingerprint': ?instance.offerFingerprint,
};

const _$DeviceCanvasStreamStatusOutcomeEnumMap = {
  DeviceCanvasStreamStatusOutcome.active: 'active',
  DeviceCanvasStreamStatusOutcome.inactive: 'inactive',
  DeviceCanvasStreamStatusOutcome.controllerConflict: 'controllerConflict',
  DeviceCanvasStreamStatusOutcome.unavailable: 'unavailable',
  DeviceCanvasStreamStatusOutcome.unauthorized: 'unauthorized',
  DeviceCanvasStreamStatusOutcome.unknown: 'unknown',
};

_DeviceCanvasStreamStopRequest _$DeviceCanvasStreamStopRequestFromJson(
  Map json,
) => _DeviceCanvasStreamStopRequest(
  expectedBridgeId: json['expectedBridgeId'] as String,
  sessionId: json['sessionId'] as String,
  deviceKey: json['deviceKey'] as String,
  expectedClaimRevision: (json['expectedClaimRevision'] as num).toInt(),
  leaseId: json['leaseId'] as String,
);

Map<String, dynamic> _$DeviceCanvasStreamStopRequestToJson(
  _DeviceCanvasStreamStopRequest instance,
) => <String, dynamic>{
  'expectedBridgeId': instance.expectedBridgeId,
  'sessionId': instance.sessionId,
  'deviceKey': instance.deviceKey,
  'expectedClaimRevision': instance.expectedClaimRevision,
  'leaseId': instance.leaseId,
};

_DeviceCanvasStreamStopResponse _$DeviceCanvasStreamStopResponseFromJson(
  Map json,
) => _DeviceCanvasStreamStopResponse(
  outcome: $enumDecode(
    _$DeviceCanvasStreamStopOutcomeEnumMap,
    json['outcome'],
    unknownValue: DeviceCanvasStreamStopOutcome.unknown,
  ),
);

Map<String, dynamic> _$DeviceCanvasStreamStopResponseToJson(
  _DeviceCanvasStreamStopResponse instance,
) => <String, dynamic>{
  'outcome': _$DeviceCanvasStreamStopOutcomeEnumMap[instance.outcome]!,
};

const _$DeviceCanvasStreamStopOutcomeEnumMap = {
  DeviceCanvasStreamStopOutcome.stopped: 'stopped',
  DeviceCanvasStreamStopOutcome.alreadyStopped: 'alreadyStopped',
  DeviceCanvasStreamStopOutcome.unauthorized: 'unauthorized',
  DeviceCanvasStreamStopOutcome.unknown: 'unknown',
};

_DeviceCanvasSessionStatusRequest _$DeviceCanvasSessionStatusRequestFromJson(
  Map json,
) => _DeviceCanvasSessionStatusRequest(sessionId: json['sessionId'] as String);

Map<String, dynamic> _$DeviceCanvasSessionStatusRequestToJson(
  _DeviceCanvasSessionStatusRequest instance,
) => <String, dynamic>{'sessionId': instance.sessionId};

_DeviceCanvasClaimRequest _$DeviceCanvasClaimRequestFromJson(Map json) =>
    _DeviceCanvasClaimRequest(
      expectedBridgeId: json['expectedBridgeId'] as String,
      sessionId: json['sessionId'] as String,
      deviceKey: json['deviceKey'] as String,
      reassign: json['reassign'] as bool? ?? false,
      expectedOwnerSessionId: json['expectedOwnerSessionId'] as String?,
      expectedClaimRevision: (json['expectedClaimRevision'] as num?)?.toInt(),
    );

Map<String, dynamic> _$DeviceCanvasClaimRequestToJson(
  _DeviceCanvasClaimRequest instance,
) => <String, dynamic>{
  'expectedBridgeId': instance.expectedBridgeId,
  'sessionId': instance.sessionId,
  'deviceKey': instance.deviceKey,
  'reassign': instance.reassign,
  'expectedOwnerSessionId': ?instance.expectedOwnerSessionId,
  'expectedClaimRevision': ?instance.expectedClaimRevision,
};

_DeviceCanvasReleaseRequest _$DeviceCanvasReleaseRequestFromJson(Map json) =>
    _DeviceCanvasReleaseRequest(
      expectedBridgeId: json['expectedBridgeId'] as String,
      sessionId: json['sessionId'] as String,
      deviceKey: json['deviceKey'] as String,
      expectedClaimRevision: (json['expectedClaimRevision'] as num).toInt(),
    );

Map<String, dynamic> _$DeviceCanvasReleaseRequestToJson(
  _DeviceCanvasReleaseRequest instance,
) => <String, dynamic>{
  'expectedBridgeId': instance.expectedBridgeId,
  'sessionId': instance.sessionId,
  'deviceKey': instance.deviceKey,
  'expectedClaimRevision': instance.expectedClaimRevision,
};

_DeviceCanvasClientCapabilities _$DeviceCanvasClientCapabilitiesFromJson(
  Map json,
) => _DeviceCanvasClientCapabilities(
  localView: json['localView'] as bool? ?? false,
  remoteVideo: json['remoteVideo'] as bool? ?? false,
  remoteControl: json['remoteControl'] as bool? ?? false,
  input: json['input'] as bool? ?? false,
);

Map<String, dynamic> _$DeviceCanvasClientCapabilitiesToJson(
  _DeviceCanvasClientCapabilities instance,
) => <String, dynamic>{
  'localView': instance.localView,
  'remoteVideo': instance.remoteVideo,
  'remoteControl': instance.remoteControl,
  'input': instance.input,
};

_DeviceCanvasClientDimensions _$DeviceCanvasClientDimensionsFromJson(
  Map json,
) => _DeviceCanvasClientDimensions(
  width: (json['width'] as num).toInt(),
  height: (json['height'] as num).toInt(),
);

Map<String, dynamic> _$DeviceCanvasClientDimensionsToJson(
  _DeviceCanvasClientDimensions instance,
) => <String, dynamic>{'width': instance.width, 'height': instance.height};

_DeviceCanvasClientDescriptor _$DeviceCanvasClientDescriptorFromJson(
  Map json,
) => _DeviceCanvasClientDescriptor(
  platform: $enumDecode(
    _$DeviceCanvasClientPlatformEnumMap,
    json['platform'],
    unknownValue: DeviceCanvasClientPlatform.unknown,
  ),
  displayName: json['displayName'] as String,
  runtimeDescription: json['runtimeDescription'] as String,
  modelDescription: json['modelDescription'] as String,
  dimensions: json['dimensions'] == null
      ? null
      : DeviceCanvasClientDimensions.fromJson(
          Map<String, dynamic>.from(json['dimensions'] as Map),
        ),
  orientation: $enumDecodeNullable(
    _$DeviceCanvasClientOrientationEnumMap,
    json['orientation'],
    unknownValue: DeviceCanvasClientOrientation.unknown,
  ),
  capabilities: DeviceCanvasClientCapabilities.fromJson(
    Map<String, dynamic>.from(json['capabilities'] as Map),
  ),
);

Map<String, dynamic> _$DeviceCanvasClientDescriptorToJson(
  _DeviceCanvasClientDescriptor instance,
) => <String, dynamic>{
  'platform': _$DeviceCanvasClientPlatformEnumMap[instance.platform]!,
  'displayName': instance.displayName,
  'runtimeDescription': instance.runtimeDescription,
  'modelDescription': instance.modelDescription,
  'dimensions': ?instance.dimensions?.toJson(),
  'orientation': ?_$DeviceCanvasClientOrientationEnumMap[instance.orientation],
  'capabilities': instance.capabilities.toJson(),
};

const _$DeviceCanvasClientPlatformEnumMap = {
  DeviceCanvasClientPlatform.ios: 'ios',
  DeviceCanvasClientPlatform.android: 'android',
  DeviceCanvasClientPlatform.unknown: 'unknown',
};

const _$DeviceCanvasClientOrientationEnumMap = {
  DeviceCanvasClientOrientation.portrait: 'portrait',
  DeviceCanvasClientOrientation.landscape: 'landscape',
  DeviceCanvasClientOrientation.unknown: 'unknown',
};

_DeviceCanvasClaimStatus _$DeviceCanvasClaimStatusFromJson(Map json) =>
    _DeviceCanvasClaimStatus(
      projectId: json['projectId'] as String,
      sessionId: json['sessionId'] as String,
      revision: (json['revision'] as num).toInt(),
      claimedAt: (json['claimedAt'] as num).toInt(),
      displayTitle: json['displayTitle'] as String?,
    );

Map<String, dynamic> _$DeviceCanvasClaimStatusToJson(
  _DeviceCanvasClaimStatus instance,
) => <String, dynamic>{
  'projectId': instance.projectId,
  'sessionId': instance.sessionId,
  'revision': instance.revision,
  'claimedAt': instance.claimedAt,
  'displayTitle': ?instance.displayTitle,
};

_DeviceCanvasDeviceStatus _$DeviceCanvasDeviceStatusFromJson(Map json) =>
    _DeviceCanvasDeviceStatus(
      deviceKey: json['deviceKey'] as String,
      descriptor: json['descriptor'] == null
          ? null
          : DeviceCanvasClientDescriptor.fromJson(
              Map<String, dynamic>.from(json['descriptor'] as Map),
            ),
      claim: json['claim'] == null
          ? null
          : DeviceCanvasClaimStatus.fromJson(
              Map<String, dynamic>.from(json['claim'] as Map),
            ),
    );

Map<String, dynamic> _$DeviceCanvasDeviceStatusToJson(
  _DeviceCanvasDeviceStatus instance,
) => <String, dynamic>{
  'deviceKey': instance.deviceKey,
  'descriptor': ?instance.descriptor?.toJson(),
  'claim': ?instance.claim?.toJson(),
};

_DeviceCanvasSessionStatusResponse _$DeviceCanvasSessionStatusResponseFromJson(
  Map json,
) => _DeviceCanvasSessionStatusResponse(
  bridgeId: json['bridgeId'] as String,
  sessionId: json['sessionId'] as String,
  sessionAvailable: json['sessionAvailable'] as bool,
  projectId: json['projectId'] as String?,
  connection:
      $enumDecodeNullable(
        _$DeviceCanvasClientConnectionStatusEnumMap,
        json['connection'],
        unknownValue: DeviceCanvasClientConnectionStatus.unknown,
      ) ??
      DeviceCanvasClientConnectionStatus.unknown,
  devices:
      (json['devices'] as List<dynamic>?)
          ?.map(
            (e) => DeviceCanvasDeviceStatus.fromJson(
              Map<String, dynamic>.from(e as Map),
            ),
          )
          .toList() ??
      const <DeviceCanvasDeviceStatus>[],
  inventoryTruncated: json['inventoryTruncated'] as bool? ?? false,
  supportsReassignment: json['supportsReassignment'] as bool? ?? false,
);

Map<String, dynamic> _$DeviceCanvasSessionStatusResponseToJson(
  _DeviceCanvasSessionStatusResponse instance,
) => <String, dynamic>{
  'bridgeId': instance.bridgeId,
  'sessionId': instance.sessionId,
  'sessionAvailable': instance.sessionAvailable,
  'projectId': ?instance.projectId,
  'connection':
      _$DeviceCanvasClientConnectionStatusEnumMap[instance.connection]!,
  'devices': instance.devices.map((e) => e.toJson()).toList(),
  'inventoryTruncated': instance.inventoryTruncated,
  'supportsReassignment': instance.supportsReassignment,
};

const _$DeviceCanvasClientConnectionStatusEnumMap = {
  DeviceCanvasClientConnectionStatus.disconnected: 'disconnected',
  DeviceCanvasClientConnectionStatus.connected: 'connected',
  DeviceCanvasClientConnectionStatus.unknown: 'unknown',
};

_DeviceCanvasMutationResponse _$DeviceCanvasMutationResponseFromJson(
  Map json,
) => _DeviceCanvasMutationResponse(
  outcome: $enumDecode(
    _$DeviceCanvasMutationOutcomeEnumMap,
    json['outcome'],
    unknownValue: DeviceCanvasMutationOutcome.unknown,
  ),
  status: DeviceCanvasSessionStatusResponse.fromJson(
    Map<String, dynamic>.from(json['status'] as Map),
  ),
);

Map<String, dynamic> _$DeviceCanvasMutationResponseToJson(
  _DeviceCanvasMutationResponse instance,
) => <String, dynamic>{
  'outcome': _$DeviceCanvasMutationOutcomeEnumMap[instance.outcome]!,
  'status': instance.status.toJson(),
};

const _$DeviceCanvasMutationOutcomeEnumMap = {
  DeviceCanvasMutationOutcome.claimed: 'claimed',
  DeviceCanvasMutationOutcome.alreadyOwned: 'alreadyOwned',
  DeviceCanvasMutationOutcome.reassigned: 'reassigned',
  DeviceCanvasMutationOutcome.conflict: 'conflict',
  DeviceCanvasMutationOutcome.deviceUnavailable: 'deviceUnavailable',
  DeviceCanvasMutationOutcome.sessionUnavailable: 'sessionUnavailable',
  DeviceCanvasMutationOutcome.released: 'released',
  DeviceCanvasMutationOutcome.alreadyReleased: 'alreadyReleased',
  DeviceCanvasMutationOutcome.unknown: 'unknown',
};
