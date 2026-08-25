import "package:freezed_annotation/freezed_annotation.dart";

part "agent_tool_protocol.freezed.dart";
part "agent_tool_protocol.g.dart";

@freezed
sealed class const DeviceCanvasAgentToolRendezvous._() with _$DeviceCanvasAgentToolRendezvous {
  const factory({required int protocolVersion, required int port}) = _DeviceCanvasAgentToolRendezvous;

  factory fromJson(Map<String, dynamic> json) => _$DeviceCanvasAgentToolRendezvousFromJson(json);

  bool get isValid => protocolVersion > 0 && port > 0 && port <= 65535;
}

@freezed
sealed class const DeviceCanvasAgentToolRegistrationResponse._() with _$DeviceCanvasAgentToolRegistrationResponse {
  const factory({required String bearerToken}) = _DeviceCanvasAgentToolRegistrationResponse;

  factory fromJson(Map<String, dynamic> json) => _$DeviceCanvasAgentToolRegistrationResponseFromJson(json);
}

@freezed
sealed class const DeviceCanvasAgentToolListRequest._() with _$DeviceCanvasAgentToolListRequest {
  const factory({required String backendSessionId}) = _DeviceCanvasAgentToolListRequest;

  factory fromJson(Map<String, dynamic> json) => _$DeviceCanvasAgentToolListRequestFromJson(json);

  bool get isValid => backendSessionId.isNotEmpty && backendSessionId.length <= 2048;
}

@freezed
sealed class const DeviceCanvasAgentToolMutationRequest._() with _$DeviceCanvasAgentToolMutationRequest {
  const factory({required String backendSessionId, required String deviceKey}) = _DeviceCanvasAgentToolMutationRequest;

  factory fromJson(Map<String, dynamic> json) => _$DeviceCanvasAgentToolMutationRequestFromJson(json);

  bool get isValid =>
      backendSessionId.isNotEmpty &&
      backendSessionId.length <= 2048 &&
      deviceKey.isNotEmpty &&
      deviceKey.length <= 512;
}

@JsonEnum()
enum DeviceCanvasAgentToolDeviceOwnership() {
  @JsonValue("unclaimed")
  unclaimed,
  @JsonValue("currentSession")
  currentSession,
  @JsonValue("anotherSession")
  anotherSession,
}

@freezed
sealed class const DeviceCanvasAgentToolDevice._() with _$DeviceCanvasAgentToolDevice {
  const factory({
    required String deviceKey,
    required String platform,
    required String displayName,
    required String runtimeDescription,
    required String modelDescription,
    required DeviceCanvasAgentToolDeviceOwnership ownership,
  }) = _DeviceCanvasAgentToolDevice;

  factory fromJson(Map<String, dynamic> json) => _$DeviceCanvasAgentToolDeviceFromJson(json);
}

@Freezed(unionKey: "outcome", fromJson: true, toJson: true)
sealed class DeviceCanvasAgentToolResponse with _$DeviceCanvasAgentToolResponse {
  @FreezedUnionValue("listed")
  const factory listed({
    required List<DeviceCanvasAgentToolDevice> devices,
    required bool truncated,
  }) = DeviceCanvasAgentToolListedResponse;

  @FreezedUnionValue("claimed")
  const factory claimed({required String deviceKey}) = DeviceCanvasAgentToolClaimedResponse;

  @FreezedUnionValue("alreadyOwned")
  const factory alreadyOwned({required String deviceKey}) = DeviceCanvasAgentToolAlreadyOwnedResponse;

  @FreezedUnionValue("released")
  const factory released({required String deviceKey}) = DeviceCanvasAgentToolReleasedResponse;

  @FreezedUnionValue("alreadyReleased")
  const factory alreadyReleased({required String deviceKey}) = DeviceCanvasAgentToolAlreadyReleasedResponse;

  @FreezedUnionValue("conflict")
  const factory conflict({required String deviceKey}) = DeviceCanvasAgentToolConflictResponse;

  @FreezedUnionValue("deviceUnavailable")
  const factory deviceUnavailable({required String deviceKey}) = DeviceCanvasAgentToolDeviceUnavailableResponse;

  @FreezedUnionValue("sessionUnavailable")
  const factory sessionUnavailable() = DeviceCanvasAgentToolSessionUnavailableResponse;

  @FreezedUnionValue("integrationUnavailable")
  const factory integrationUnavailable() = DeviceCanvasAgentToolIntegrationUnavailableResponse;

  @FreezedUnionValue("bridgeUnavailable")
  const factory bridgeUnavailable() = DeviceCanvasAgentToolBridgeUnavailableResponse;

  @FreezedUnionValue("invalidRequest")
  const factory invalidRequest() = DeviceCanvasAgentToolInvalidRequestResponse;

  @FreezedUnionValue("internalError")
  const factory internalError() = DeviceCanvasAgentToolInternalErrorResponse;

  factory fromJson(Map<String, dynamic> json) => _$DeviceCanvasAgentToolResponseFromJson(json);
}
