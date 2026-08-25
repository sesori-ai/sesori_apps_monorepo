import "dart:async";

import "package:injectable/injectable.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../api/device_canvas_api.dart";
import "../capabilities/relay/relay_client.dart";
import "models/device_canvas_result.dart";

@lazySingleton
class DeviceCanvasRepository({required final DeviceCanvasApi _api}) {
  Future<DeviceCanvasStatusResult> getSessionStatus({required String sessionId}) async {
    return switch (await _api.getSessionStatus(sessionId: sessionId)) {
      SuccessResponse(:final data) => DeviceCanvasStatusSupported(status: data),
      ErrorResponse(error: NonSuccessCodeError(errorCode: 404)) => const DeviceCanvasStatusUnsupported(),
      ErrorResponse(:final error) => DeviceCanvasStatusFailure(error: error),
    };
  }

  Future<DeviceCanvasMutationResult> claim({
    required String expectedBridgeId,
    required String sessionId,
    required String deviceKey,
    required bool reassign,
    required String? expectedOwnerSessionId,
    required int? expectedClaimRevision,
  }) async {
    return _mapMutation(
      await _api.claim(
        expectedBridgeId: expectedBridgeId,
        sessionId: sessionId,
        deviceKey: deviceKey,
        reassign: reassign,
        expectedOwnerSessionId: expectedOwnerSessionId,
        expectedClaimRevision: expectedClaimRevision,
      ),
    );
  }

  Future<DeviceCanvasMutationResult> release({
    required String expectedBridgeId,
    required String sessionId,
    required String deviceKey,
    required int expectedClaimRevision,
  }) async {
    return _mapMutation(
      await _api.release(
        expectedBridgeId: expectedBridgeId,
        sessionId: sessionId,
        deviceKey: deviceKey,
        expectedClaimRevision: expectedClaimRevision,
      ),
    );
  }

  DeviceCanvasMutationResult _mapMutation(ApiResponse<DeviceCanvasMutationResponse> response) {
    return switch (response) {
      SuccessResponse(:final data) => DeviceCanvasMutationCommitted(response: data),
      ErrorResponse(error: NonSuccessCodeError(errorCode: 404)) => const DeviceCanvasMutationUnsupported(),
      // A bridge-side 5xx may happen after the database mutation committed but
      // before an authoritative response could be projected or delivered.
      ErrorResponse(error: NonSuccessCodeError(:final errorCode)) when errorCode >= 500 && errorCode < 600 =>
        const DeviceCanvasMutationUncertain(),
      ErrorResponse(
        error: JsonParsingError() ||
            EmptyResponseError() ||
            DartHttpClientError(innerError: TimeoutException() || RelayResponseLostException()),
      ) =>
        const DeviceCanvasMutationUncertain(),
      ErrorResponse(:final error) => DeviceCanvasMutationFailure(error: error),
    };
  }
}
