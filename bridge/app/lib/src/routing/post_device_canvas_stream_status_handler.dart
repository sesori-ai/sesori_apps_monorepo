import "package:sesori_shared/sesori_shared.dart";

import "../services/device_canvas_stream_service.dart";
import "request_handler.dart";
import "routed_request.dart";

class PostDeviceCanvasStreamStatusHandler({required final DeviceCanvasStreamService _service})
    extends ContextBodyRequestHandler<DeviceCanvasStreamStatusRequest, DeviceCanvasStreamStatusResponse> {
  this
    : super(
        HttpMethod.post,
        "/device-canvas/stream/status",
        fromJson: DeviceCanvasStreamStatusRequest.fromJson,
      );

  @override
  Future<DeviceCanvasStreamStatusResponse> handle(
    RelayRequest request, {
    required DeviceCanvasStreamStatusRequest body,
    required RoutedRequestContext context,
  }) {
    if (!body.isValid) throw buildErrorResponse(request, 400, "invalid Device Canvas stream status request");
    final relayContext = switch (context) {
      final RelayRoutedRequestContext relayContext => relayContext,
      LocalRoutedRequestContext() => throw buildErrorResponse(request, 403, "relay connection required"),
    };
    return _service.status(
      client: DeviceCanvasStreamClient(
        connectionId: relayContext.connectionId,
        connectionIncarnation: relayContext.connectionIncarnation,
      ),
      request: body,
    );
  }
}
