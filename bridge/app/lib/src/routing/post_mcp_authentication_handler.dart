import "package:sesori_shared/sesori_shared.dart";

import "../services/mcp_authentication_service.dart";
import "request_handler.dart";

class PostMcpAuthenticationHandler({required final McpAuthenticationService _service})
    extends BodyRequestHandler<McpAuthenticationStartRequest, McpAuthenticationResult> {
  this : super(HttpMethod.post, "/mcp/authentication", fromJson: McpAuthenticationStartRequest.fromJson);

  @override
  Future<McpAuthenticationResult> handle(RelayRequest request, {required McpAuthenticationStartRequest body}) async {
    requireNonEmpty(request: request, value: body.pluginId, label: "plugin id");
    requireNonEmpty(request: request, value: body.target.serverKey, label: "server key");
    switch (body.target.scope) {
      case McpHarnessScope():
        break;
      case McpProjectScope(:final projectId):
        requireNonEmpty(request: request, value: projectId, label: "project id");
      case McpSessionScope(:final sessionId):
        requireNonEmpty(request: request, value: sessionId, label: "session id");
    }
    return await _service.start(request: body);
  }
}
