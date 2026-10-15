import "package:sesori_shared/sesori_shared.dart";

import "../services/mcp_authentication_service.dart";
import "request_handler.dart";

class PostMcpAuthenticationCancelHandler({required final McpAuthenticationService _service})
    extends BodyRequestHandler<McpAuthenticationCancelRequest, McpAuthenticationResult> {
  this : super(HttpMethod.post, "/mcp/authentication/cancel", fromJson: McpAuthenticationCancelRequest.fromJson);

  @override
  Future<McpAuthenticationResult> handle(RelayRequest request, {required McpAuthenticationCancelRequest body}) async {
    requireNonEmpty(request: request, value: body.attemptId, label: "attempt id");
    return await _service.cancel(request: body);
  }
}
