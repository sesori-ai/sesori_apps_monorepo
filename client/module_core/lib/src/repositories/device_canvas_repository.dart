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

  Future<DeviceCanvasStreamStartResult> startStream({required DeviceCanvasStreamStartRequest request}) async {
    return switch (await _api.startStream(request: request)) {
      SuccessResponse(:final data) => DeviceCanvasStreamStartSupported(response: data),
      ErrorResponse(error: NonSuccessCodeError(errorCode: 404)) => const DeviceCanvasStreamStartUnsupported(),
      ErrorResponse(:final error) when _isUncertainStreamWriteError(error) => const DeviceCanvasStreamStartUncertain(),
      ErrorResponse(:final error) => DeviceCanvasStreamStartFailure(error: error),
    };
  }

  Future<DeviceCanvasStreamPrepareResult> prepareStream({required DeviceCanvasStreamPrepareRequest request}) async {
    return switch (await _api.prepareStream(request: request)) {
      SuccessResponse(:final data) => DeviceCanvasStreamPrepareSupported(response: data),
      ErrorResponse(error: NonSuccessCodeError(errorCode: 404)) => const DeviceCanvasStreamPrepareUnsupported(),
      ErrorResponse(:final error) when _isUncertainStreamWriteError(error) =>
        const DeviceCanvasStreamPrepareUncertain(),
      ErrorResponse(:final error) => DeviceCanvasStreamPrepareFailure(error: error),
    };
  }

  Future<DeviceCanvasStreamStatusResult> statusStream({required DeviceCanvasStreamStatusRequest request}) async {
    return switch (await _api.statusStream(request: request)) {
      SuccessResponse(:final data) => DeviceCanvasStreamStatusSupported(response: data),
      ErrorResponse(error: NonSuccessCodeError(errorCode: 404)) => const DeviceCanvasStreamStatusUnsupported(),
      ErrorResponse(:final error) => DeviceCanvasStreamStatusFailure(error: error),
    };
  }

  Future<DeviceCanvasStreamStopResult> stopStream({required DeviceCanvasStreamStopRequest request}) async {
    return switch (await _api.stopStream(request: request)) {
      SuccessResponse(:final data) => DeviceCanvasStreamStopSupported(response: data),
      ErrorResponse(error: NonSuccessCodeError(errorCode: 404)) => const DeviceCanvasStreamStopUnsupported(),
      ErrorResponse(:final error) when _isUncertainStreamWriteError(error) => const DeviceCanvasStreamStopUncertain(),
      ErrorResponse(:final error) => DeviceCanvasStreamStopFailure(error: error),
    };
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

  bool _isUncertainStreamWriteError(ApiError error) {
    return switch (error) {
      NonSuccessCodeError(:final errorCode) => errorCode >= 500 && errorCode < 600,
      JsonParsingError() || EmptyResponseError() => true,
      DartHttpClientError(:final innerError) =>
        innerError is TimeoutException || innerError is RelayResponseLostException,
      GenericError() || NotAuthenticatedError() => false,
    };
  }
}
