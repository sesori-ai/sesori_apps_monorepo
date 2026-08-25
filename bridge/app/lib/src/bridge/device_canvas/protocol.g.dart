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
