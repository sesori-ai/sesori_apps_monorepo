import "package:sesori_shared/sesori_shared.dart";

import "../services/mcp_service.dart";
import "request_handler.dart";

class PostMcpEntryActionHandler({required final McpService _mcpService})
    extends BodyRequestHandler<McpEntryActionRequest, McpEntryActionResult> {
  this : super(HttpMethod.post, "/mcp/entry/action", fromJson: McpEntryActionRequest.fromJson);

  @override
  Future<McpEntryActionResult> handle(RelayRequest request, {required McpEntryActionRequest body}) async {
    requireNonEmpty(request: request, value: body.pluginId, label: "plugin id");
    final target = body.action.entryTarget;
    switch (target) {
      case McpServerTarget(:final serverKey):
        requireNonEmpty(request: request, value: serverKey, label: "server key");
      case McpConnectorOfferTarget(:final offerKey):
        requireNonEmpty(request: request, value: offerKey, label: "connector offer key");
    }
    switch (target.scope) {
      case McpHarnessScope():
        break;
      case McpProjectScope(:final projectId):
        requireNonEmpty(request: request, value: projectId, label: "project id");
      case McpSessionScope(:final sessionId):
        requireNonEmpty(request: request, value: sessionId, label: "session id");
    }
    return await _mcpService.execute(request: body);
  }
}
