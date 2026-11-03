import "package:sesori_shared/sesori_shared.dart";

import "../services/mcp_authentication_service.dart";
import "request_handler.dart";

class GetMcpAuthenticationHandler({required final McpAuthenticationService _service})
    extends GetRequestHandler<McpAuthenticationResult> {
  this : super(path: "/mcp/authentication");

  @override
  Future<McpAuthenticationResult> handle({required RelayRequest request}) async => _service.current;
}
