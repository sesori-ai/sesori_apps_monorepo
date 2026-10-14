import "package:sesori_shared/sesori_shared.dart";

import "../services/mcp_authentication_service.dart";
import "request_handler.dart";

class PostMcpAuthenticationContinueHandler({required final McpAuthenticationService _service})
    extends BodyRequestHandler<McpAuthenticationContinueRequest, McpAuthenticationResult> {
  this : super(HttpMethod.post, "/mcp/authentication/continue", fromJson: McpAuthenticationContinueRequest.fromJson);

  @override
  Future<McpAuthenticationResult> handle(RelayRequest request, {required McpAuthenticationContinueRequest body}) async {
    requireNonEmpty(request: request, value: body.attemptId, label: "attempt id");
    requireNonEmpty(request: request, value: body.callbackUrl, label: "callback");
    return await _service.continueAuthentication(request: body);
  }
}
