import "dart:convert";

import "package:freezed_annotation/freezed_annotation.dart";

part "device_canvas_client.freezed.dart";
part "device_canvas_client.g.dart";

const int maxDeviceCanvasClientIdentifierLength = 2048;
const int maxDeviceCanvasClientDeviceKeyLength = 512;
const int maxDeviceCanvasStreamLeaseIdLength = 128;
const int maxDeviceCanvasRtcSdpBytes = 262144;
const int maxDeviceCanvasRtcFingerprintLength = 256;
const int maxDeviceCanvasIceCandidates = 64;
const int maxDeviceCanvasIceCandidateLength = 2048;
const int maxDeviceCanvasIceCandidateSdpMidLength = 128;
const int maxDeviceCanvasTurnUrls = 8;
const int maxDeviceCanvasTurnUrlLength = 2048;
const int maxDeviceCanvasTurnUsernameLength = 512;
const int maxDeviceCanvasTurnCredentialLength = 512;

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

enum DeviceCanvasRtcDescriptionType() {
  @JsonValue("offer")
  offer,
  @JsonValue("answer")
  answer,
  @JsonValue("unknown")
  unknown,
}

enum DeviceCanvasStreamStartOutcome() {
  @JsonValue("started")
  started,
  @JsonValue("controllerConflict")
  controllerConflict,
  @JsonValue("unavailable")
  unavailable,
  @JsonValue("unauthorized")
  unauthorized,
  @JsonValue("unsupported")
  unsupported,
  @JsonValue("unknown")
  unknown,
}

enum DeviceCanvasStreamStatusOutcome() {
  @JsonValue("active")
  active,
  @JsonValue("inactive")
  inactive,
  @JsonValue("controllerConflict")
  controllerConflict,
  @JsonValue("unavailable")
  unavailable,
  @JsonValue("unauthorized")
  unauthorized,
  @JsonValue("unknown")
  unknown,
}

enum DeviceCanvasStreamStopOutcome() {
  @JsonValue("stopped")
  stopped,
  @JsonValue("alreadyStopped")
  alreadyStopped,
  @JsonValue("unauthorized")
  unauthorized,
  @JsonValue("unknown")
  unknown,
}

@Freezed(fromJson: true, toJson: true, toStringOverride: false)
sealed class const DeviceCanvasRtcDescription._() with _$DeviceCanvasRtcDescription {
  const factory({
    @JsonKey(unknownEnumValue: DeviceCanvasRtcDescriptionType.unknown)
    required DeviceCanvasRtcDescriptionType type,
    required String sdp,
    required String fingerprint,
  }) = _DeviceCanvasRtcDescription;

  factory fromJson(Map<String, dynamic> json) => _$DeviceCanvasRtcDescriptionFromJson(json);

  bool get isValid {
    if (type == DeviceCanvasRtcDescriptionType.unknown ||
        utf8.encode(sdp).length > maxDeviceCanvasRtcSdpBytes ||
        fingerprint.isEmpty ||
        fingerprint.length > maxDeviceCanvasRtcFingerprintLength ||
        !RegExp(r"^sha-256 (?:[0-9A-Fa-f]{2}:){31}[0-9A-Fa-f]{2}$").hasMatch(fingerprint)) {
      return false;
    }
    final fingerprintLines = sdp.split(RegExp(r"\r?\n")).where((line) => line.startsWith("a=fingerprint:"));
    return fingerprintLines.length == 1 && fingerprintLines.single == "a=fingerprint:$fingerprint";
  }
}

@Freezed(fromJson: true, toJson: true, toStringOverride: false)
sealed class const DeviceCanvasIceCandidate._() with _$DeviceCanvasIceCandidate {
  const factory({
    required String candidate,
    required String sdpMid,
    required int sdpMLineIndex,
  }) = _DeviceCanvasIceCandidate;

  factory fromJson(Map<String, dynamic> json) => _$DeviceCanvasIceCandidateFromJson(json);

  bool get isValid =>
      candidate.isNotEmpty &&
      candidate.length <= maxDeviceCanvasIceCandidateLength &&
      sdpMid.isNotEmpty &&
      sdpMid.length <= maxDeviceCanvasIceCandidateSdpMidLength &&
      sdpMLineIndex >= 0;
}

@Freezed(fromJson: true, toJson: true, toStringOverride: false)
sealed class const DeviceCanvasTurnConfiguration._() with _$DeviceCanvasTurnConfiguration {
  const factory({
    required List<String> urls,
    required String username,
    required String credential,
    required int expiresAt,
  }) = _DeviceCanvasTurnConfiguration;

  factory fromJson(Map<String, dynamic> json) => _$DeviceCanvasTurnConfigurationFromJson(json);

  bool get isValid =>
      urls.isNotEmpty &&
      urls.length <= maxDeviceCanvasTurnUrls &&
      urls.every((url) => url.isNotEmpty && url.length <= maxDeviceCanvasTurnUrlLength) &&
      username.isNotEmpty &&
      username.length <= maxDeviceCanvasTurnUsernameLength &&
      credential.isNotEmpty &&
      credential.length <= maxDeviceCanvasTurnCredentialLength &&
      expiresAt > 0;
}

@Freezed(fromJson: true, toJson: true, toStringOverride: false)
sealed class const DeviceCanvasStreamStartRequest._() with _$DeviceCanvasStreamStartRequest {
  const factory({
    required String expectedBridgeId,
    required String sessionId,
    required String deviceKey,
    required int expectedClaimRevision,
    required bool control,
    required DeviceCanvasRtcDescription offer,
    @Default(<DeviceCanvasIceCandidate>[]) List<DeviceCanvasIceCandidate> iceCandidates,
  }) = _DeviceCanvasStreamStartRequest;

  factory fromJson(Map<String, dynamic> json) => _$DeviceCanvasStreamStartRequestFromJson(json);

  bool get isValid =>
      _isValidDeviceCanvasStreamIdentity(
        expectedBridgeId: expectedBridgeId,
        sessionId: sessionId,
        deviceKey: deviceKey,
        expectedClaimRevision: expectedClaimRevision,
      ) &&
      offer.type == DeviceCanvasRtcDescriptionType.offer &&
      offer.isValid &&
      iceCandidates.length <= maxDeviceCanvasIceCandidates &&
      iceCandidates.every((candidate) => candidate.isValid);
}

@Freezed(fromJson: true, toJson: true, toStringOverride: false)
sealed class const DeviceCanvasStreamStartResponse._() with _$DeviceCanvasStreamStartResponse {
  const factory({
    @JsonKey(unknownEnumValue: DeviceCanvasStreamStartOutcome.unknown)
    required DeviceCanvasStreamStartOutcome outcome,
    required String? leaseId,
    required int? expiresAt,
    required DeviceCanvasRtcDescription? answer,
    @Default(<DeviceCanvasIceCandidate>[]) List<DeviceCanvasIceCandidate> iceCandidates,
    required DeviceCanvasTurnConfiguration? turn,
  }) = _DeviceCanvasStreamStartResponse;

  factory fromJson(Map<String, dynamic> json) => _$DeviceCanvasStreamStartResponseFromJson(json);

  bool get isValid => switch (outcome) {
    DeviceCanvasStreamStartOutcome.started => _isValidDeviceCanvasStreamPayload(
      leaseId: leaseId,
      expiresAt: expiresAt,
      answer: answer,
      iceCandidates: iceCandidates,
      turn: turn,
    ),
    DeviceCanvasStreamStartOutcome.controllerConflict ||
    DeviceCanvasStreamStartOutcome.unavailable ||
    DeviceCanvasStreamStartOutcome.unauthorized ||
    DeviceCanvasStreamStartOutcome.unsupported => _hasNoDeviceCanvasStreamPayload(
      leaseId: leaseId,
      expiresAt: expiresAt,
      answer: answer,
      iceCandidates: iceCandidates,
      turn: turn,
    ),
    DeviceCanvasStreamStartOutcome.unknown => false,
  };
}

@Freezed(fromJson: true, toJson: true, toStringOverride: false)
sealed class const DeviceCanvasStreamStatusRequest._() with _$DeviceCanvasStreamStatusRequest {
  const factory({
    required String expectedBridgeId,
    required String sessionId,
    required String deviceKey,
    required int expectedClaimRevision,
  }) = _DeviceCanvasStreamStatusRequest;

  factory fromJson(Map<String, dynamic> json) => _$DeviceCanvasStreamStatusRequestFromJson(json);

  bool get isValid => _isValidDeviceCanvasStreamIdentity(
    expectedBridgeId: expectedBridgeId,
    sessionId: sessionId,
    deviceKey: deviceKey,
    expectedClaimRevision: expectedClaimRevision,
  );
}

@Freezed(fromJson: true, toJson: true, toStringOverride: false)
sealed class const DeviceCanvasStreamStatusResponse._() with _$DeviceCanvasStreamStatusResponse {
  const factory({
    @JsonKey(unknownEnumValue: DeviceCanvasStreamStatusOutcome.unknown)
    required DeviceCanvasStreamStatusOutcome outcome,
    required String? leaseId,
    required int? expiresAt,
    required DeviceCanvasRtcDescription? answer,
    @Default(<DeviceCanvasIceCandidate>[]) List<DeviceCanvasIceCandidate> iceCandidates,
    required DeviceCanvasTurnConfiguration? turn,
  }) = _DeviceCanvasStreamStatusResponse;

  factory fromJson(Map<String, dynamic> json) => _$DeviceCanvasStreamStatusResponseFromJson(json);

  bool get isValid => switch (outcome) {
    DeviceCanvasStreamStatusOutcome.active => _isValidDeviceCanvasStreamPayload(
      leaseId: leaseId,
      expiresAt: expiresAt,
      answer: answer,
      iceCandidates: iceCandidates,
      turn: turn,
    ),
    DeviceCanvasStreamStatusOutcome.inactive ||
    DeviceCanvasStreamStatusOutcome.controllerConflict ||
    DeviceCanvasStreamStatusOutcome.unavailable ||
    DeviceCanvasStreamStatusOutcome.unauthorized => _hasNoDeviceCanvasStreamPayload(
      leaseId: leaseId,
      expiresAt: expiresAt,
      answer: answer,
      iceCandidates: iceCandidates,
      turn: turn,
    ),
    DeviceCanvasStreamStatusOutcome.unknown => false,
  };
}

@Freezed(fromJson: true, toJson: true, toStringOverride: false)
sealed class const DeviceCanvasStreamStopRequest._() with _$DeviceCanvasStreamStopRequest {
  const factory({
    required String expectedBridgeId,
    required String sessionId,
    required String deviceKey,
    required int expectedClaimRevision,
    required String leaseId,
  }) = _DeviceCanvasStreamStopRequest;

  factory fromJson(Map<String, dynamic> json) => _$DeviceCanvasStreamStopRequestFromJson(json);

  bool get isValid =>
      _isValidDeviceCanvasStreamIdentity(
        expectedBridgeId: expectedBridgeId,
        sessionId: sessionId,
        deviceKey: deviceKey,
        expectedClaimRevision: expectedClaimRevision,
      ) &&
      leaseId.isNotEmpty &&
      leaseId.length <= maxDeviceCanvasStreamLeaseIdLength;
}

@Freezed(fromJson: true, toJson: true)
sealed class const DeviceCanvasStreamStopResponse._() with _$DeviceCanvasStreamStopResponse {
  const factory({
    @JsonKey(unknownEnumValue: DeviceCanvasStreamStopOutcome.unknown) required DeviceCanvasStreamStopOutcome outcome,
  }) = _DeviceCanvasStreamStopResponse;

  factory fromJson(Map<String, dynamic> json) => _$DeviceCanvasStreamStopResponseFromJson(json);

  bool get isValid => outcome != DeviceCanvasStreamStopOutcome.unknown;
}

bool _isValidDeviceCanvasStreamIdentity({
  required String expectedBridgeId,
  required String sessionId,
  required String deviceKey,
  required int expectedClaimRevision,
}) =>
    expectedBridgeId.isNotEmpty &&
    expectedBridgeId.length <= maxDeviceCanvasClientIdentifierLength &&
    sessionId.isNotEmpty &&
    sessionId.length <= maxDeviceCanvasClientIdentifierLength &&
    deviceKey.isNotEmpty &&
    deviceKey.length <= maxDeviceCanvasClientDeviceKeyLength &&
    expectedClaimRevision > 0;

bool _isValidDeviceCanvasStreamPayload({
  required String? leaseId,
  required int? expiresAt,
  required DeviceCanvasRtcDescription? answer,
  required List<DeviceCanvasIceCandidate> iceCandidates,
  required DeviceCanvasTurnConfiguration? turn,
}) =>
    leaseId != null &&
    leaseId.isNotEmpty &&
    leaseId.length <= maxDeviceCanvasStreamLeaseIdLength &&
    expiresAt != null &&
    expiresAt > 0 &&
    answer != null &&
    answer.type == DeviceCanvasRtcDescriptionType.answer &&
    answer.isValid &&
    iceCandidates.length <= maxDeviceCanvasIceCandidates &&
    iceCandidates.every((candidate) => candidate.isValid) &&
    (turn?.isValid ?? true);

bool _hasNoDeviceCanvasStreamPayload({
  required String? leaseId,
  required int? expiresAt,
  required DeviceCanvasRtcDescription? answer,
  required List<DeviceCanvasIceCandidate> iceCandidates,
  required DeviceCanvasTurnConfiguration? turn,
}) =>
    leaseId == null && expiresAt == null && answer == null && iceCandidates.isEmpty && turn == null;

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
