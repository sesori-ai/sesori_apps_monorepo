import "package:freezed_annotation/freezed_annotation.dart";

part "device_canvas_client.freezed.dart";
part "device_canvas_client.g.dart";

const int maxDeviceCanvasClientIdentifierLength = 2048;
const int maxDeviceCanvasClientDeviceKeyLength = 512;

enum DeviceCanvasClientConnectionStatus() {
  @JsonValue("disconnected")
  disconnected,
  @JsonValue("connected")
  connected,
  @JsonValue("unknown")
  unknown,
}

enum DeviceCanvasClientPlatform() {
  @JsonValue("ios")
  ios,
  @JsonValue("android")
  android,
  @JsonValue("unknown")
  unknown,
}

enum DeviceCanvasClientOrientation() {
  @JsonValue("portrait")
  portrait,
  @JsonValue("landscape")
  landscape,
  @JsonValue("unknown")
  unknown,
}

enum DeviceCanvasMutationOutcome() {
  @JsonValue("claimed")
  claimed,
  @JsonValue("alreadyOwned")
  alreadyOwned,
  @JsonValue("reassigned")
  reassigned,
  @JsonValue("conflict")
  conflict,
  @JsonValue("deviceUnavailable")
  deviceUnavailable,
  @JsonValue("sessionUnavailable")
  sessionUnavailable,
  @JsonValue("released")
  released,
  @JsonValue("alreadyReleased")
  alreadyReleased,
  @JsonValue("unknown")
  unknown,
}

@Freezed(fromJson: true, toJson: true)
sealed class const DeviceCanvasSessionStatusRequest._() with _$DeviceCanvasSessionStatusRequest {
  const factory({required String sessionId}) = _DeviceCanvasSessionStatusRequest;

  factory fromJson(Map<String, dynamic> json) => _$DeviceCanvasSessionStatusRequestFromJson(json);

  bool get isValid => sessionId.isNotEmpty && sessionId.length <= maxDeviceCanvasClientIdentifierLength;
}

@Freezed(fromJson: true, toJson: true)
sealed class const DeviceCanvasClaimRequest._() with _$DeviceCanvasClaimRequest {
  const factory({
    required String expectedBridgeId,
    required String sessionId,
    required String deviceKey,
    @Default(false) bool reassign,
    required String? expectedOwnerSessionId,
    required int? expectedClaimRevision,
  }) = _DeviceCanvasClaimRequest;

  factory fromJson(Map<String, dynamic> json) => _$DeviceCanvasClaimRequestFromJson(json);

  bool get isValid {
    if (expectedBridgeId.isEmpty ||
        expectedBridgeId.length > maxDeviceCanvasClientIdentifierLength ||
        sessionId.isEmpty ||
        sessionId.length > maxDeviceCanvasClientIdentifierLength ||
        deviceKey.isEmpty ||
        deviceKey.length > maxDeviceCanvasClientDeviceKeyLength) {
      return false;
    }
    if (!reassign) return expectedOwnerSessionId == null && expectedClaimRevision == null;
    final ownerSessionId = expectedOwnerSessionId;
    final claimRevision = expectedClaimRevision;
    return ownerSessionId != null &&
        ownerSessionId.isNotEmpty &&
        ownerSessionId != sessionId &&
        ownerSessionId.length <= maxDeviceCanvasClientIdentifierLength &&
        claimRevision != null &&
        claimRevision > 0;
  }
}

@Freezed(fromJson: true, toJson: true)
sealed class const DeviceCanvasReleaseRequest._() with _$DeviceCanvasReleaseRequest {
  const factory({
    required String expectedBridgeId,
    required String sessionId,
    required String deviceKey,
    required int expectedClaimRevision,
  }) = _DeviceCanvasReleaseRequest;

  factory fromJson(Map<String, dynamic> json) => _$DeviceCanvasReleaseRequestFromJson(json);

  bool get isValid =>
      expectedBridgeId.isNotEmpty &&
      expectedBridgeId.length <= maxDeviceCanvasClientIdentifierLength &&
      sessionId.isNotEmpty &&
      sessionId.length <= maxDeviceCanvasClientIdentifierLength &&
      deviceKey.isNotEmpty &&
      deviceKey.length <= maxDeviceCanvasClientDeviceKeyLength &&
      expectedClaimRevision > 0;
}

@Freezed(fromJson: true, toJson: true)
sealed class DeviceCanvasClientCapabilities with _$DeviceCanvasClientCapabilities {
  const factory({
    @Default(false) bool localView,
    @Default(false) bool remoteVideo,
    @Default(false) bool remoteControl,
    @Default(false) bool input,
  }) = _DeviceCanvasClientCapabilities;

  factory fromJson(Map<String, dynamic> json) => _$DeviceCanvasClientCapabilitiesFromJson(json);
}

@Freezed(fromJson: true, toJson: true)
sealed class DeviceCanvasClientDimensions with _$DeviceCanvasClientDimensions {
  const factory({required int width, required int height}) = _DeviceCanvasClientDimensions;

  factory fromJson(Map<String, dynamic> json) => _$DeviceCanvasClientDimensionsFromJson(json);
}

@Freezed(fromJson: true, toJson: true)
sealed class DeviceCanvasClientDescriptor with _$DeviceCanvasClientDescriptor {
  const factory({
    @JsonKey(unknownEnumValue: DeviceCanvasClientPlatform.unknown) required DeviceCanvasClientPlatform platform,
    required String displayName,
    required String runtimeDescription,
    required String modelDescription,
    required DeviceCanvasClientDimensions? dimensions,
    @JsonKey(unknownEnumValue: DeviceCanvasClientOrientation.unknown)
    required DeviceCanvasClientOrientation? orientation,
    required DeviceCanvasClientCapabilities capabilities,
  }) = _DeviceCanvasClientDescriptor;

  factory fromJson(Map<String, dynamic> json) => _$DeviceCanvasClientDescriptorFromJson(json);
}

@Freezed(fromJson: true, toJson: true)
sealed class DeviceCanvasClaimStatus with _$DeviceCanvasClaimStatus {
  const factory({
    required String projectId,
    required String sessionId,
    required int revision,
    required int claimedAt,
    required String? displayTitle,
  }) = _DeviceCanvasClaimStatus;

  factory fromJson(Map<String, dynamic> json) => _$DeviceCanvasClaimStatusFromJson(json);
}

@Freezed(fromJson: true, toJson: true)
sealed class DeviceCanvasDeviceStatus with _$DeviceCanvasDeviceStatus {
  const factory({
    required String deviceKey,
    required DeviceCanvasClientDescriptor? descriptor,
    required DeviceCanvasClaimStatus? claim,
  }) = _DeviceCanvasDeviceStatus;

  factory fromJson(Map<String, dynamic> json) => _$DeviceCanvasDeviceStatusFromJson(json);
}

@Freezed(fromJson: true, toJson: true)
sealed class DeviceCanvasSessionStatusResponse with _$DeviceCanvasSessionStatusResponse {
  const factory({
    required String bridgeId,
    required String sessionId,
    required bool sessionAvailable,
    required String? projectId,
    @JsonKey(unknownEnumValue: DeviceCanvasClientConnectionStatus.unknown)
    @Default(DeviceCanvasClientConnectionStatus.unknown)
    DeviceCanvasClientConnectionStatus connection,
    @Default(<DeviceCanvasDeviceStatus>[]) List<DeviceCanvasDeviceStatus> devices,
    @Default(false) bool inventoryTruncated,
    @Default(false) bool supportsReassignment,
  }) = _DeviceCanvasSessionStatusResponse;

  factory fromJson(Map<String, dynamic> json) => _$DeviceCanvasSessionStatusResponseFromJson(json);
}

@Freezed(fromJson: true, toJson: true)
sealed class DeviceCanvasMutationResponse with _$DeviceCanvasMutationResponse {
  const factory({
    @JsonKey(unknownEnumValue: DeviceCanvasMutationOutcome.unknown) required DeviceCanvasMutationOutcome outcome,
    required DeviceCanvasSessionStatusResponse status,
  }) = _DeviceCanvasMutationResponse;

  factory fromJson(Map<String, dynamic> json) => _$DeviceCanvasMutationResponseFromJson(json);
}
