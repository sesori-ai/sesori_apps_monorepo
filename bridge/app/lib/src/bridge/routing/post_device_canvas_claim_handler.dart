import "package:sesori_shared/sesori_shared.dart";

import "../services/device_canvas_client_service.dart";
import "request_handler.dart";

class PostDeviceCanvasClaimHandler({required final DeviceCanvasClientService _service})
    extends BodyRequestHandler<DeviceCanvasClaimRequest, DeviceCanvasMutationResponse> {
  this
    : super(
        HttpMethod.post,
        "/device-canvas/claim",
        fromJson: DeviceCanvasClaimRequest.fromJson,
      );

  @override
  Future<DeviceCanvasMutationResponse> handle(
    RelayRequest request, {
    required DeviceCanvasClaimRequest body,
    required Map<String, String> pathParams,
    required Map<String, String> queryParams,
    required String? fragment,
  }) async {
    if (!body.isValid) throw buildErrorResponse(request, 400, "invalid Device Canvas claim request");
    try {
      return await _service.claim(request: body);
    } on DeviceCanvasClientBridgeUnavailable {
      throw buildErrorResponse(request, 503, "bridge identity unavailable");
    }
  }
}
