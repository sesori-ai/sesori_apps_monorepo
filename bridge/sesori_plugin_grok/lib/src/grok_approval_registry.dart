import "package:acp_plugin/acp_plugin.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "api/models/grok_session_notification_dto.dart";

/// Grok asks its own permission before every MCP tool. For Sesori's tools the
/// bridge already asks before any change, so this registry allows those calls
/// once without asking again.
class GrokApprovalRegistry({
  required AcpStdioClient client,
  required super.emit,
  required super.idGenerator,
  required super.activeSessionResolver,
  required final bool Function({required String sessionId}) _holdsSesoriServer,
}) extends AcpApprovalRegistry {
  this
    : super(
        respond: (id, result) => client.respondToServerRequest(id: id, result: result),
        respondError: (id, code, message) =>
            client.respondToServerRequestWithError(id: id, code: code, message: message),
      );

  /// Grok runs MCP tools through its `use_tool` tool, whose input names the
  /// tool as `<server>__<tool>`. Sesori's tool names are snake case without a
  /// double underscore, so the pattern cannot match a tool of another server
  /// whose name only starts with `sesori_bridge`. A session given Sesori's
  /// server has no user server of that name, because the session's one wins.
  static final _sesoriToolName = RegExp("^${sesoriMcpServerName}__[a-z][a-z0-9]*(_[a-z0-9]+)*\$");

  @override
  bool preAllowsPermission({required String sessionId, required Map<String, dynamic> params}) {
    final GrokPermissionToolCallDto? toolCall;
    try {
      toolCall = GrokPermissionRequestDto.fromJson(params).toolCall;
    } on Object catch (error, stackTrace) {
      Log.w("[grok] permission request could not be parsed; asking the user", error, stackTrace);
      return false;
    }
    if (toolCall?.meta?.tool?.name != "use_tool") return false;
    final toolName = toolCall?.rawInput?.toolName;
    return toolName != null && _sesoriToolName.hasMatch(toolName) && _holdsSesoriServer(sessionId: sessionId);
  }
}
