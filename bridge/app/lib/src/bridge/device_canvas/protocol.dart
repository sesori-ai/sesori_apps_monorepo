import "package:freezed_annotation/freezed_annotation.dart";
import "package:sesori_shared/sesori_shared.dart";

part "protocol.freezed.dart";
part "protocol.g.dart";

const int deviceCanvasIpcProtocolVersion = 3;

@JsonEnum()
enum DeviceCanvasPlatform() {
  @JsonValue("ios")
  ios,
  @JsonValue("android")
  android,
}

@JsonEnum()
enum DeviceCanvasOrientation() {
  @JsonValue("portrait")
  portrait,
  @JsonValue("landscape")
  landscape,
}

@JsonEnum()
enum DeviceCanvasStreamStartFailureReason() {
  @JsonValue("unsupported")
  unsupported,
  @JsonValue("invalidOffer")
  invalidOffer,
  @JsonValue("peerSetupFailed")
  peerSetupFailed,
  @JsonValue("unknown")
  unknown,
}

@JsonEnum()
enum DeviceCanvasStreamCloseReason() {
  @JsonValue("stopped")
  stopped,
  @JsonValue("failed")
  failed,
  @JsonValue("unknown")
  unknown,
}

@JsonEnum()
enum DeviceCanvasStreamRevokeReason() {
  @JsonValue("stopped")
  stopped,
  @JsonValue("expired")
  expired,
  @JsonValue("claimChanged")
  claimChanged,
  @JsonValue("clientDisconnected")
  clientDisconnected,
  @JsonValue("canvasDisconnected")
  canvasDisconnected,
  @JsonValue("deviceUnavailable")
  deviceUnavailable,
  @JsonValue("bridgeShutdown")
  bridgeShutdown,
  @JsonValue("startFailed")
  startFailed,
}

@freezed
sealed class const DeviceCanvasDimensions._() with _$DeviceCanvasDimensions {
  const factory({required int width, required int height}) = _DeviceCanvasDimensions;

  factory fromJson(Map<String, dynamic> json) => _$DeviceCanvasDimensionsFromJson(json);

  bool get isValid => width > 0 && height > 0;
}

@freezed
sealed class const DeviceCanvasCapabilities._() with _$DeviceCanvasCapabilities {
  const factory({
    required bool localView,
    required bool remoteVideo,
    required bool remoteControl,
    required bool input,
  }) = _DeviceCanvasCapabilities;

  factory fromJson(Map<String, dynamic> json) => _$DeviceCanvasCapabilitiesFromJson(json);
}

@freezed
sealed class const DeviceCanvasDescriptor._() with _$DeviceCanvasDescriptor {
  const factory({
    required String deviceKey,
    required DeviceCanvasPlatform platform,
    required String displayName,
    required String runtimeDescription,
    required String modelDescription,
    required DeviceCanvasDimensions? dimensions,
    required DeviceCanvasOrientation? orientation,
    required DeviceCanvasCapabilities capabilities,
  }) = _DeviceCanvasDescriptor;

  factory fromJson(Map<String, dynamic> json) => _$DeviceCanvasDescriptorFromJson(json);

  bool get isValid =>
      deviceKey.isNotEmpty &&
      displayName.isNotEmpty &&
      runtimeDescription.isNotEmpty &&
      modelDescription.isNotEmpty &&
      (dimensions?.isValid ?? true);
}

@Freezed(unionKey: "type", fromJson: true, toJson: true, toStringOverride: false)
sealed class DeviceCanvasInboundMessage with _$DeviceCanvasInboundMessage {
  @FreezedUnionValue("hello")
  const factory hello({
    required int protocolVersion,
    required String canvasInstanceId,
    required DeviceCanvasCapabilities capabilities,
  }) = DeviceCanvasHello;

  @FreezedUnionValue("inventorySnapshot")
  const factory inventorySnapshot({
    required List<DeviceCanvasDescriptor> devices,
  }) = DeviceCanvasInventorySnapshot;

  @FreezedUnionValue("heartbeat")
  const factory heartbeat({
    required String canvasInstanceId,
    required int observedAt,
  }) = DeviceCanvasHeartbeat;

  @FreezedUnionValue("streamStarted")
  const factory streamStarted({
    required String requestId,
    required String leaseId,
    required DeviceCanvasRtcDescription answer,
    required List<DeviceCanvasIceCandidate> iceCandidates,
  }) = DeviceCanvasStreamStartedMessage;

  @FreezedUnionValue("streamStartFailed")
  const factory streamStartFailed({
    required String requestId,
    required String leaseId,
    @JsonKey(unknownEnumValue: DeviceCanvasStreamStartFailureReason.unknown)
    required DeviceCanvasStreamStartFailureReason reason,
  }) = DeviceCanvasStreamStartFailedMessage;

  @FreezedUnionValue("streamClosed")
  const factory streamClosed({
    required String leaseId,
    @JsonKey(unknownEnumValue: DeviceCanvasStreamCloseReason.unknown) required DeviceCanvasStreamCloseReason reason,
  }) = DeviceCanvasStreamClosedMessage;

  factory fromJson(Map<String, dynamic> json) => _$DeviceCanvasInboundMessageFromJson(json);
}

@freezed
sealed class const DeviceCanvasClaimProjectionDto._() with _$DeviceCanvasClaimProjectionDto {
  const factory({
    required String bridgeId,
    required String sessionId,
    required String deviceKey,
    required int revision,
    required String? displayTitle,
  }) = _DeviceCanvasClaimProjectionDto;

  factory fromJson(Map<String, dynamic> json) => _$DeviceCanvasClaimProjectionDtoFromJson(json);
}

@Freezed(unionKey: "type", fromJson: true, toJson: true, toStringOverride: false)
sealed class DeviceCanvasOutboundMessage with _$DeviceCanvasOutboundMessage {
  @FreezedUnionValue("helloAccepted")
  const factory helloAccepted({required int protocolVersion, required String bridgeId}) =
      DeviceCanvasHelloAccepted;

  @FreezedUnionValue("claimsSnapshot")
  const factory claimsSnapshot({required List<DeviceCanvasClaimProjectionDto> claims}) =
      DeviceCanvasClaimsSnapshot;

  @FreezedUnionValue("claimUpdated")
  const factory claimUpdated({required DeviceCanvasClaimProjectionDto claim}) =
      DeviceCanvasClaimUpdatedMessage;

  @FreezedUnionValue("claimRemoved")
  const factory claimRemoved({
    required String bridgeId,
    required String deviceKey,
    required int revision,
  }) = DeviceCanvasClaimRemovedMessage;

  @FreezedUnionValue("compatibilityStatus")
  const factory compatibilityStatus({
    required bool supported,
    required int protocolVersion,
    required String reason,
  }) = DeviceCanvasCompatibilityStatus;

  @FreezedUnionValue("streamStart")
  const factory streamStart({
    required String requestId,
    required String leaseId,
    required String bridgeId,
    required String sessionId,
    required String deviceKey,
    required int claimRevision,
    required int expiresAt,
    required bool control,
    required DeviceCanvasRtcDescription offer,
    required List<DeviceCanvasIceCandidate> iceCandidates,
    required DeviceCanvasTurnConfiguration? turn,
  }) = DeviceCanvasStreamStartMessage;

  @FreezedUnionValue("streamRevoke")
  const factory streamRevoke({required String leaseId, required DeviceCanvasStreamRevokeReason reason}) =
      DeviceCanvasStreamRevokeMessage;

  factory fromJson(Map<String, dynamic> json) => _$DeviceCanvasOutboundMessageFromJson(json);
}
