// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'protocol.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_DeviceCanvasDimensions _$DeviceCanvasDimensionsFromJson(Map json) =>
    _DeviceCanvasDimensions(
      width: (json['width'] as num).toInt(),
      height: (json['height'] as num).toInt(),
    );

Map<String, dynamic> _$DeviceCanvasDimensionsToJson(
  _DeviceCanvasDimensions instance,
) => <String, dynamic>{'width': instance.width, 'height': instance.height};

_DeviceCanvasCapabilities _$DeviceCanvasCapabilitiesFromJson(Map json) =>
    _DeviceCanvasCapabilities(
      localView: json['localView'] as bool,
      remoteVideo: json['remoteVideo'] as bool,
      remoteControl: json['remoteControl'] as bool,
      input: json['input'] as bool,
    );

Map<String, dynamic> _$DeviceCanvasCapabilitiesToJson(
  _DeviceCanvasCapabilities instance,
) => <String, dynamic>{
  'localView': instance.localView,
  'remoteVideo': instance.remoteVideo,
  'remoteControl': instance.remoteControl,
  'input': instance.input,
};

_DeviceCanvasDescriptor _$DeviceCanvasDescriptorFromJson(Map json) =>
    _DeviceCanvasDescriptor(
      deviceKey: json['deviceKey'] as String,
      platform: $enumDecode(_$DeviceCanvasPlatformEnumMap, json['platform']),
      displayName: json['displayName'] as String,
      runtimeDescription: json['runtimeDescription'] as String,
      modelDescription: json['modelDescription'] as String,
      dimensions: json['dimensions'] == null
          ? null
          : DeviceCanvasDimensions.fromJson(
              Map<String, dynamic>.from(json['dimensions'] as Map),
            ),
      orientation: $enumDecodeNullable(
        _$DeviceCanvasOrientationEnumMap,
        json['orientation'],
      ),
      capabilities: DeviceCanvasCapabilities.fromJson(
        Map<String, dynamic>.from(json['capabilities'] as Map),
      ),
    );

Map<String, dynamic> _$DeviceCanvasDescriptorToJson(
  _DeviceCanvasDescriptor instance,
) => <String, dynamic>{
  'deviceKey': instance.deviceKey,
  'platform': _$DeviceCanvasPlatformEnumMap[instance.platform]!,
  'displayName': instance.displayName,
  'runtimeDescription': instance.runtimeDescription,
  'modelDescription': instance.modelDescription,
  'dimensions': ?instance.dimensions?.toJson(),
  'orientation': ?_$DeviceCanvasOrientationEnumMap[instance.orientation],
  'capabilities': instance.capabilities.toJson(),
};

const _$DeviceCanvasPlatformEnumMap = {
  DeviceCanvasPlatform.ios: 'ios',
  DeviceCanvasPlatform.android: 'android',
};

const _$DeviceCanvasOrientationEnumMap = {
  DeviceCanvasOrientation.portrait: 'portrait',
  DeviceCanvasOrientation.landscape: 'landscape',
};

DeviceCanvasHello _$DeviceCanvasHelloFromJson(Map json) => DeviceCanvasHello(
  protocolVersion: (json['protocolVersion'] as num).toInt(),
  canvasInstanceId: json['canvasInstanceId'] as String,
  capabilities: DeviceCanvasCapabilities.fromJson(
    Map<String, dynamic>.from(json['capabilities'] as Map),
  ),
  $type: json['type'] as String?,
);

Map<String, dynamic> _$DeviceCanvasHelloToJson(DeviceCanvasHello instance) =>
    <String, dynamic>{
      'protocolVersion': instance.protocolVersion,
      'canvasInstanceId': instance.canvasInstanceId,
      'capabilities': instance.capabilities.toJson(),
      'type': instance.$type,
    };

DeviceCanvasInventorySnapshot _$DeviceCanvasInventorySnapshotFromJson(
  Map json,
) => DeviceCanvasInventorySnapshot(
  devices: (json['devices'] as List<dynamic>)
      .map(
        (e) => DeviceCanvasDescriptor.fromJson(
          Map<String, dynamic>.from(e as Map),
        ),
      )
      .toList(),
  $type: json['type'] as String?,
);

Map<String, dynamic> _$DeviceCanvasInventorySnapshotToJson(
  DeviceCanvasInventorySnapshot instance,
) => <String, dynamic>{
  'devices': instance.devices.map((e) => e.toJson()).toList(),
  'type': instance.$type,
};

DeviceCanvasHeartbeat _$DeviceCanvasHeartbeatFromJson(Map json) =>
    DeviceCanvasHeartbeat(
      canvasInstanceId: json['canvasInstanceId'] as String,
      observedAt: (json['observedAt'] as num).toInt(),
      $type: json['type'] as String?,
    );

Map<String, dynamic> _$DeviceCanvasHeartbeatToJson(
  DeviceCanvasHeartbeat instance,
) => <String, dynamic>{
  'canvasInstanceId': instance.canvasInstanceId,
  'observedAt': instance.observedAt,
  'type': instance.$type,
};

DeviceCanvasStreamStartedMessage _$DeviceCanvasStreamStartedMessageFromJson(
  Map json,
) => DeviceCanvasStreamStartedMessage(
  requestId: json['requestId'] as String,
  leaseId: json['leaseId'] as String,
  answer: DeviceCanvasRtcDescription.fromJson(
    Map<String, dynamic>.from(json['answer'] as Map),
  ),
  iceCandidates: (json['iceCandidates'] as List<dynamic>)
      .map(
        (e) => DeviceCanvasIceCandidate.fromJson(
          Map<String, dynamic>.from(e as Map),
        ),
      )
      .toList(),
  $type: json['type'] as String?,
);

Map<String, dynamic> _$DeviceCanvasStreamStartedMessageToJson(
  DeviceCanvasStreamStartedMessage instance,
) => <String, dynamic>{
  'requestId': instance.requestId,
  'leaseId': instance.leaseId,
  'answer': instance.answer.toJson(),
  'iceCandidates': instance.iceCandidates.map((e) => e.toJson()).toList(),
  'type': instance.$type,
};

DeviceCanvasStreamStartFailedMessage
_$DeviceCanvasStreamStartFailedMessageFromJson(Map json) =>
    DeviceCanvasStreamStartFailedMessage(
      requestId: json['requestId'] as String,
      leaseId: json['leaseId'] as String,
      reason: $enumDecode(
        _$DeviceCanvasStreamStartFailureReasonEnumMap,
        json['reason'],
        unknownValue: DeviceCanvasStreamStartFailureReason.unknown,
      ),
      $type: json['type'] as String?,
    );

Map<String, dynamic> _$DeviceCanvasStreamStartFailedMessageToJson(
  DeviceCanvasStreamStartFailedMessage instance,
) => <String, dynamic>{
  'requestId': instance.requestId,
  'leaseId': instance.leaseId,
  'reason': _$DeviceCanvasStreamStartFailureReasonEnumMap[instance.reason]!,
  'type': instance.$type,
};

const _$DeviceCanvasStreamStartFailureReasonEnumMap = {
  DeviceCanvasStreamStartFailureReason.unsupported: 'unsupported',
  DeviceCanvasStreamStartFailureReason.invalidOffer: 'invalidOffer',
  DeviceCanvasStreamStartFailureReason.peerSetupFailed: 'peerSetupFailed',
  DeviceCanvasStreamStartFailureReason.unknown: 'unknown',
};

DeviceCanvasStreamClosedMessage _$DeviceCanvasStreamClosedMessageFromJson(
  Map json,
) => DeviceCanvasStreamClosedMessage(
  leaseId: json['leaseId'] as String,
  reason: $enumDecode(
    _$DeviceCanvasStreamCloseReasonEnumMap,
    json['reason'],
    unknownValue: DeviceCanvasStreamCloseReason.unknown,
  ),
  $type: json['type'] as String?,
);

Map<String, dynamic> _$DeviceCanvasStreamClosedMessageToJson(
  DeviceCanvasStreamClosedMessage instance,
) => <String, dynamic>{
  'leaseId': instance.leaseId,
  'reason': _$DeviceCanvasStreamCloseReasonEnumMap[instance.reason]!,
  'type': instance.$type,
};

const _$DeviceCanvasStreamCloseReasonEnumMap = {
  DeviceCanvasStreamCloseReason.stopped: 'stopped',
  DeviceCanvasStreamCloseReason.failed: 'failed',
  DeviceCanvasStreamCloseReason.unknown: 'unknown',
};

_DeviceCanvasClaimProjectionDto _$DeviceCanvasClaimProjectionDtoFromJson(
  Map json,
) => _DeviceCanvasClaimProjectionDto(
  bridgeId: json['bridgeId'] as String,
  sessionId: json['sessionId'] as String,
  deviceKey: json['deviceKey'] as String,
  revision: (json['revision'] as num).toInt(),
  displayTitle: json['displayTitle'] as String?,
);

Map<String, dynamic> _$DeviceCanvasClaimProjectionDtoToJson(
  _DeviceCanvasClaimProjectionDto instance,
) => <String, dynamic>{
  'bridgeId': instance.bridgeId,
  'sessionId': instance.sessionId,
  'deviceKey': instance.deviceKey,
  'revision': instance.revision,
  'displayTitle': ?instance.displayTitle,
};

DeviceCanvasHelloAccepted _$DeviceCanvasHelloAcceptedFromJson(Map json) =>
    DeviceCanvasHelloAccepted(
      protocolVersion: (json['protocolVersion'] as num).toInt(),
      bridgeId: json['bridgeId'] as String,
      $type: json['type'] as String?,
    );

Map<String, dynamic> _$DeviceCanvasHelloAcceptedToJson(
  DeviceCanvasHelloAccepted instance,
) => <String, dynamic>{
  'protocolVersion': instance.protocolVersion,
  'bridgeId': instance.bridgeId,
  'type': instance.$type,
};

DeviceCanvasClaimsSnapshot _$DeviceCanvasClaimsSnapshotFromJson(Map json) =>
    DeviceCanvasClaimsSnapshot(
      claims: (json['claims'] as List<dynamic>)
          .map(
            (e) => DeviceCanvasClaimProjectionDto.fromJson(
              Map<String, dynamic>.from(e as Map),
            ),
          )
          .toList(),
      $type: json['type'] as String?,
    );

Map<String, dynamic> _$DeviceCanvasClaimsSnapshotToJson(
  DeviceCanvasClaimsSnapshot instance,
) => <String, dynamic>{
  'claims': instance.claims.map((e) => e.toJson()).toList(),
  'type': instance.$type,
};

DeviceCanvasClaimUpdatedMessage _$DeviceCanvasClaimUpdatedMessageFromJson(
  Map json,
) => DeviceCanvasClaimUpdatedMessage(
  claim: DeviceCanvasClaimProjectionDto.fromJson(
    Map<String, dynamic>.from(json['claim'] as Map),
  ),
  $type: json['type'] as String?,
);

Map<String, dynamic> _$DeviceCanvasClaimUpdatedMessageToJson(
  DeviceCanvasClaimUpdatedMessage instance,
) => <String, dynamic>{
  'claim': instance.claim.toJson(),
  'type': instance.$type,
};

DeviceCanvasClaimRemovedMessage _$DeviceCanvasClaimRemovedMessageFromJson(
  Map json,
) => DeviceCanvasClaimRemovedMessage(
  bridgeId: json['bridgeId'] as String,
  deviceKey: json['deviceKey'] as String,
  revision: (json['revision'] as num).toInt(),
  $type: json['type'] as String?,
);

Map<String, dynamic> _$DeviceCanvasClaimRemovedMessageToJson(
  DeviceCanvasClaimRemovedMessage instance,
) => <String, dynamic>{
  'bridgeId': instance.bridgeId,
  'deviceKey': instance.deviceKey,
  'revision': instance.revision,
  'type': instance.$type,
};

DeviceCanvasCompatibilityStatus _$DeviceCanvasCompatibilityStatusFromJson(
  Map json,
) => DeviceCanvasCompatibilityStatus(
  supported: json['supported'] as bool,
  protocolVersion: (json['protocolVersion'] as num).toInt(),
  reason: json['reason'] as String,
  $type: json['type'] as String?,
);

Map<String, dynamic> _$DeviceCanvasCompatibilityStatusToJson(
  DeviceCanvasCompatibilityStatus instance,
) => <String, dynamic>{
  'supported': instance.supported,
  'protocolVersion': instance.protocolVersion,
  'reason': instance.reason,
  'type': instance.$type,
};

DeviceCanvasStreamStartMessage _$DeviceCanvasStreamStartMessageFromJson(
  Map json,
) => DeviceCanvasStreamStartMessage(
  requestId: json['requestId'] as String,
  leaseId: json['leaseId'] as String,
  bridgeId: json['bridgeId'] as String,
  sessionId: json['sessionId'] as String,
  deviceKey: json['deviceKey'] as String,
  claimRevision: (json['claimRevision'] as num).toInt(),
  expiresAt: (json['expiresAt'] as num).toInt(),
  control: json['control'] as bool,
  offer: DeviceCanvasRtcDescription.fromJson(
    Map<String, dynamic>.from(json['offer'] as Map),
  ),
  iceCandidates: (json['iceCandidates'] as List<dynamic>)
      .map(
        (e) => DeviceCanvasIceCandidate.fromJson(
          Map<String, dynamic>.from(e as Map),
        ),
      )
      .toList(),
  turn: json['turn'] == null
      ? null
      : DeviceCanvasTurnConfiguration.fromJson(
          Map<String, dynamic>.from(json['turn'] as Map),
        ),
  $type: json['type'] as String?,
);

Map<String, dynamic> _$DeviceCanvasStreamStartMessageToJson(
  DeviceCanvasStreamStartMessage instance,
) => <String, dynamic>{
  'requestId': instance.requestId,
  'leaseId': instance.leaseId,
  'bridgeId': instance.bridgeId,
  'sessionId': instance.sessionId,
  'deviceKey': instance.deviceKey,
  'claimRevision': instance.claimRevision,
  'expiresAt': instance.expiresAt,
  'control': instance.control,
  'offer': instance.offer.toJson(),
  'iceCandidates': instance.iceCandidates.map((e) => e.toJson()).toList(),
  'turn': ?instance.turn?.toJson(),
  'type': instance.$type,
};

DeviceCanvasStreamRevokeMessage _$DeviceCanvasStreamRevokeMessageFromJson(
  Map json,
) => DeviceCanvasStreamRevokeMessage(
  leaseId: json['leaseId'] as String,
  reason: $enumDecode(_$DeviceCanvasStreamRevokeReasonEnumMap, json['reason']),
  $type: json['type'] as String?,
);

Map<String, dynamic> _$DeviceCanvasStreamRevokeMessageToJson(
  DeviceCanvasStreamRevokeMessage instance,
) => <String, dynamic>{
  'leaseId': instance.leaseId,
  'reason': _$DeviceCanvasStreamRevokeReasonEnumMap[instance.reason]!,
  'type': instance.$type,
};

const _$DeviceCanvasStreamRevokeReasonEnumMap = {
  DeviceCanvasStreamRevokeReason.stopped: 'stopped',
  DeviceCanvasStreamRevokeReason.expired: 'expired',
  DeviceCanvasStreamRevokeReason.claimChanged: 'claimChanged',
  DeviceCanvasStreamRevokeReason.clientDisconnected: 'clientDisconnected',
  DeviceCanvasStreamRevokeReason.canvasDisconnected: 'canvasDisconnected',
  DeviceCanvasStreamRevokeReason.deviceUnavailable: 'deviceUnavailable',
  DeviceCanvasStreamRevokeReason.bridgeShutdown: 'bridgeShutdown',
  DeviceCanvasStreamRevokeReason.startFailed: 'startFailed',
};
