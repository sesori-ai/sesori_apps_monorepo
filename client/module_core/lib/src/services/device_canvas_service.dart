import "package:injectable/injectable.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../repositories/device_canvas_repository.dart";
import "../repositories/models/device_canvas_result.dart";

@lazySingleton
class DeviceCanvasService({required final DeviceCanvasRepository _repository}) {
  Future<DeviceCanvasStatusResult> getSessionStatus({required String sessionId}) {
    return _repository.getSessionStatus(sessionId: sessionId);
  }

  Future<DeviceCanvasMutationResult> claim({
    required String expectedBridgeId,
    required String sessionId,
    required String deviceKey,
    required bool reassign,
    required String? expectedOwnerSessionId,
    required int? expectedClaimRevision,
  }) {
    return _repository.claim(
      expectedBridgeId: expectedBridgeId,
      sessionId: sessionId,
      deviceKey: deviceKey,
      reassign: reassign,
      expectedOwnerSessionId: expectedOwnerSessionId,
      expectedClaimRevision: expectedClaimRevision,
    );
  }

  Future<DeviceCanvasMutationResult> release({
    required String expectedBridgeId,
    required String sessionId,
    required String deviceKey,
    required int expectedClaimRevision,
  }) {
    return _repository.release(
      expectedBridgeId: expectedBridgeId,
      sessionId: sessionId,
      deviceKey: deviceKey,
      expectedClaimRevision: expectedClaimRevision,
    );
  }

  Future<DeviceCanvasStreamStartResult> startStream({required DeviceCanvasStreamStartRequest request}) {
    return _repository.startStream(request: request);
  }

  Future<DeviceCanvasStreamPrepareResult> prepareStream({required DeviceCanvasStreamPrepareRequest request}) {
    return _repository.prepareStream(request: request);
  }

  Future<DeviceCanvasStreamStatusResult> statusStream({required DeviceCanvasStreamStatusRequest request}) {
    return _repository.statusStream(request: request);
  }

  Future<DeviceCanvasStreamStopResult> stopStream({required DeviceCanvasStreamStopRequest request}) {
    return _repository.stopStream(request: request);
  }
}
