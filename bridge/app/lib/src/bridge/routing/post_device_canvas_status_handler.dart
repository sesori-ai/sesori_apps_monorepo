import "package:sesori_shared/sesori_shared.dart";

import "../services/device_canvas_client_service.dart";
import "request_handler.dart";

class PostDeviceCanvasStatusHandler({required final DeviceCanvasClientService _service})
    extends BodyRequestHandler<DeviceCanvasSessionStatusRequest, DeviceCanvasSessionStatusResponse> {
  this
    : super(
        HttpMethod.post,
        "/device-canvas/status",
        fromJson: DeviceCanvasSessionStatusRequest.fromJson,
      );

  @override
  Future<DeviceCanvasSessionStatusResponse> handle(
    RelayRequest request, {
    required DeviceCanvasSessionStatusRequest body,
    required Map<String, String> pathParams,
    required Map<String, String> queryParams,
    required String? fragment,
  }) async {
    if (!body.isValid) throw buildErrorResponse(request, 400, "invalid Device Canvas status request");
    try {
      return await _service.status(sessionId: body.sessionId);
    } on DeviceCanvasClientBridgeUnavailable {
      throw buildErrorResponse(request, 503, "bridge identity unavailable");
    }
  }
}
