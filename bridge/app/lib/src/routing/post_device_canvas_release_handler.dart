import "package:sesori_shared/sesori_shared.dart";

import "../services/device_canvas_client_service.dart";
import "request_handler.dart";

class PostDeviceCanvasReleaseHandler({required final DeviceCanvasClientService _service})
    extends BodyRequestHandler<DeviceCanvasReleaseRequest, DeviceCanvasMutationResponse> {
  this
    : super(
        HttpMethod.post,
        "/device-canvas/release",
        fromJson: DeviceCanvasReleaseRequest.fromJson,
      );

  @override
  Future<DeviceCanvasMutationResponse> handle(
    RelayRequest request, {
    required DeviceCanvasReleaseRequest body,
  }) async {
    if (!body.isValid) throw buildErrorResponse(request, 400, "invalid Device Canvas release request");
    try {
      return await _service.release(request: body);
    } on DeviceCanvasClientBridgeUnavailable {
      throw buildErrorResponse(request, 503, "bridge identity unavailable");
    }
  }
}
