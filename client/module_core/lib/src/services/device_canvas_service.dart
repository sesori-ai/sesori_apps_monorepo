import "package:injectable/injectable.dart";

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
}
