import "package:injectable/injectable.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_shared/sesori_shared.dart";

import "client/relay_http_client.dart";

@lazySingleton
class DeviceCanvasApi({required final RelayHttpApiClient _client}) {
  Future<ApiResponse<DeviceCanvasSessionStatusResponse>> getSessionStatus({required String sessionId}) {
    return _client.post(
      "/device-canvas/status",
      fromJson: DeviceCanvasSessionStatusResponse.fromJson,
      body: DeviceCanvasSessionStatusRequest(sessionId: sessionId).toJson(),
    );
  }

  Future<ApiResponse<DeviceCanvasMutationResponse>> claim({
    required String expectedBridgeId,
    required String sessionId,
    required String deviceKey,
    required bool reassign,
    required String? expectedOwnerSessionId,
    required int? expectedClaimRevision,
  }) {
    return _client.post(
      "/device-canvas/claim",
      fromJson: DeviceCanvasMutationResponse.fromJson,
      body: DeviceCanvasClaimRequest(
        expectedBridgeId: expectedBridgeId,
        sessionId: sessionId,
        deviceKey: deviceKey,
        reassign: reassign,
        expectedOwnerSessionId: expectedOwnerSessionId,
        expectedClaimRevision: expectedClaimRevision,
      ).toJson(),
    );
  }

  Future<ApiResponse<DeviceCanvasMutationResponse>> release({
    required String expectedBridgeId,
    required String sessionId,
    required String deviceKey,
    required int expectedClaimRevision,
  }) {
    return _client.post(
      "/device-canvas/release",
      fromJson: DeviceCanvasMutationResponse.fromJson,
      body: DeviceCanvasReleaseRequest(
        expectedBridgeId: expectedBridgeId,
        sessionId: sessionId,
        deviceKey: deviceKey,
        expectedClaimRevision: expectedClaimRevision,
      ).toJson(),
    );
  }
}
