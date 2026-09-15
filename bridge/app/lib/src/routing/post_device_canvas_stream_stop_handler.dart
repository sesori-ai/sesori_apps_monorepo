import "package:sesori_shared/sesori_shared.dart";

import "../services/device_canvas_stream_service.dart";
import "request_handler.dart";
import "routed_request.dart";

class PostDeviceCanvasStreamStopHandler({required final DeviceCanvasStreamService _service})
    extends ContextBodyRequestHandler<DeviceCanvasStreamStopRequest, DeviceCanvasStreamStopResponse> {
  this
    : super(
        HttpMethod.post,
        "/device-canvas/stream/stop",
        fromJson: DeviceCanvasStreamStopRequest.fromJson,
      );

  @override
  Future<DeviceCanvasStreamStopResponse> handle(
    RelayRequest request, {
    required DeviceCanvasStreamStopRequest body,
    required RoutedRequestContext context,
  }) {
    if (!body.isValid) throw buildErrorResponse(request, 400, "invalid Device Canvas stream stop request");
    final relayContext = switch (context) {
      final RelayRoutedRequestContext relayContext => relayContext,
      LocalRoutedRequestContext() => throw buildErrorResponse(request, 403, "relay connection required"),
    };
    return _service.stop(
      client: DeviceCanvasStreamClient(
        connectionId: relayContext.connectionId,
        connectionIncarnation: relayContext.connectionIncarnation,
      ),
      request: body,
    );
  }
}
