import "package:sesori_shared/sesori_shared.dart";

import "../repositories/mcp_repository.dart";
import "request_handler.dart";

class PostMcpInventoryHandler({required final McpRepository _mcpRepository})
    extends BodyRequestHandler<McpInventoryRequest, McpInventoryResult> {
  this : super(HttpMethod.post, "/mcp/inventory", fromJson: McpInventoryRequest.fromJson);

  @override
  Future<McpInventoryResult> handle(RelayRequest request, {required McpInventoryRequest body}) async {
    requireNonEmpty(request: request, value: body.pluginId, label: "plugin id");
    switch (body.scope) {
      case McpHarnessScope():
        break;
      case McpProjectScope(:final projectId):
        requireNonEmpty(request: request, value: projectId, label: "project id");
      case McpSessionScope(:final sessionId):
        requireNonEmpty(request: request, value: sessionId, label: "session id");
    }
    return await _mcpRepository.getInventory(pluginId: body.pluginId, scope: body.scope);
  }
}
