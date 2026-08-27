import "package:sesori_shared/sesori_shared.dart";

import "../services/device_canvas_stream_service.dart";
import "request_handler.dart";
import "routed_request.dart";

class PostDeviceCanvasStreamPrepareHandler({required final DeviceCanvasStreamService _service})
    extends ContextBodyRequestHandler<DeviceCanvasStreamPrepareRequest, DeviceCanvasStreamPrepareResponse> {
  this
    : super(
        HttpMethod.post,
        "/device-canvas/stream/prepare",
        fromJson: DeviceCanvasStreamPrepareRequest.fromJson,
      );

  @override
  Future<DeviceCanvasStreamPrepareResponse> handle(
    RelayRequest request, {
    required DeviceCanvasStreamPrepareRequest body,
    required RoutedRequestContext context,
  }) {
    if (!body.isValid) throw buildErrorResponse(request, 400, "invalid Device Canvas stream prepare request");
    final relayContext = switch (context) {
      final RelayRoutedRequestContext relayContext => relayContext,
      LocalRoutedRequestContext() => throw buildErrorResponse(request, 403, "relay connection required"),
    };
    return _service.prepare(
      client: DeviceCanvasStreamClient(
        connectionId: relayContext.connectionId,
        connectionIncarnation: relayContext.connectionIncarnation,
      ),
      request: body,
    );
  }
}
