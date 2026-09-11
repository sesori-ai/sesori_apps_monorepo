import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

/// Pure projection from active generic Cursor Task parts to terminal generic
/// cards when prompt lifecycle is the only authoritative terminal signal.
final class const CursorTaskMapper() {
  PluginMessagePart mapCancelled({required PluginMessagePartTool genericPart}) => _mapTerminalGeneric(
    genericPart: genericPart,
    status: PluginToolStatus.cancelled,
    error: null,
  );

  PluginMessagePart mapFailed({
    required PluginMessagePartTool genericPart,
    required String failureMessage,
  }) => _mapTerminalGeneric(
    genericPart: genericPart,
    status: PluginToolStatus.error,
    error: String.fromCharCodes(failureMessage.runes.take(maxToolOutputLength)),
  );

  PluginMessagePart _mapTerminalGeneric({
    required PluginMessagePartTool genericPart,
    required PluginToolStatus status,
    required String? error,
  }) => PluginMessagePart.tool(
    id: genericPart.id,
    sessionID: genericPart.sessionID,
    messageID: genericPart.messageID,
    tool: genericPart.tool,
    state: PluginToolState(
      status: status,
      title: genericPart.state.title,
      shellCommand: genericPart.state.shellCommand,
      output: null,
      error: error,
      attachments: genericPart.state.attachments,
    ),
  );
}
