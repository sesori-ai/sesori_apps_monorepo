import "package:sesori_shared/sesori_shared.dart";

import "../services/device_canvas_stream_service.dart";
import "request_handler.dart";
import "routed_request.dart";

class PostDeviceCanvasStreamStartHandler({required final DeviceCanvasStreamService _service})
    extends ContextBodyRequestHandler<DeviceCanvasStreamStartRequest, DeviceCanvasStreamStartResponse> {
  this
    : super(
        HttpMethod.post,
        "/device-canvas/stream/start",
        fromJson: DeviceCanvasStreamStartRequest.fromJson,
      );

  @override
  Future<DeviceCanvasStreamStartResponse> handle(
    RelayRequest request, {
    required DeviceCanvasStreamStartRequest body,
    required RoutedRequestContext context,
  }) {
    if (!body.isValid) throw buildErrorResponse(request, 400, "invalid Device Canvas stream start request");
    final relayContext = switch (context) {
      final RelayRoutedRequestContext relayContext => relayContext,
      LocalRoutedRequestContext() => throw buildErrorResponse(request, 403, "relay connection required"),
    };
    return _service.start(
      client: DeviceCanvasStreamClient(
        connectionId: relayContext.connectionId,
        connectionIncarnation: relayContext.connectionIncarnation,
      ),
      request: body,
    );
  }
}
