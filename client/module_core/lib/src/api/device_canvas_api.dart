import "package:injectable/injectable.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_shared/sesori_shared.dart";

import "client/relay_http_client.dart";

@lazySingleton
class DeviceCanvasApi({required final RelayHttpApiClient _client}) {
  static const Duration _streamRequestTimeout = Duration(seconds: 20);

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

  Future<ApiResponse<DeviceCanvasStreamStartResponse>> startStream({
    required DeviceCanvasStreamStartRequest request,
  }) {
    return _client.postWithTimeout(
      "/device-canvas/stream/start",
      fromJson: _parseStreamStartResponse,
      body: request.toJson(),
      timeout: _streamRequestTimeout,
    );
  }

  Future<ApiResponse<DeviceCanvasStreamStatusResponse>> statusStream({
    required DeviceCanvasStreamStatusRequest request,
  }) {
    return _client.postWithTimeout(
      "/device-canvas/stream/status",
      fromJson: _parseStreamStatusResponse,
      body: request.toJson(),
      timeout: _streamRequestTimeout,
    );
  }

  Future<ApiResponse<DeviceCanvasStreamStopResponse>> stopStream({
    required DeviceCanvasStreamStopRequest request,
  }) {
    return _client.postWithTimeout(
      "/device-canvas/stream/stop",
      fromJson: _parseStreamStopResponse,
      body: request.toJson(),
      timeout: _streamRequestTimeout,
    );
  }

  // ignore: no_slop_linter/prefer_specific_type, JSON parsing callback requires dynamic payload
  static DeviceCanvasStreamStartResponse _parseStreamStartResponse(Map<String, dynamic> json) {
    final response = DeviceCanvasStreamStartResponse.fromJson(json);
    if (!response.isValid) throw const FormatException("invalid Device Canvas stream start response");
    return response;
  }

  // ignore: no_slop_linter/prefer_specific_type, JSON parsing callback requires dynamic payload
  static DeviceCanvasStreamStatusResponse _parseStreamStatusResponse(Map<String, dynamic> json) {
    final response = DeviceCanvasStreamStatusResponse.fromJson(json);
    if (!response.isValid) throw const FormatException("invalid Device Canvas stream status response");
    return response;
  }

  // ignore: no_slop_linter/prefer_specific_type, JSON parsing callback requires dynamic payload
  static DeviceCanvasStreamStopResponse _parseStreamStopResponse(Map<String, dynamic> json) {
    final response = DeviceCanvasStreamStopResponse.fromJson(json);
    if (!response.isValid) throw const FormatException("invalid Device Canvas stream stop response");
    return response;
  }
}
