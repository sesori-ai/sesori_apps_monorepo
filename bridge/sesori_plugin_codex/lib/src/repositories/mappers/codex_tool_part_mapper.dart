import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "../models/codex_projected_tool.dart";

/// One ordinary tool projection for live upserts and saved transcript replay.
class const CodexToolPartMapper() {
  PluginMessagePart map({
    required String sessionId,
    required CodexProjectedTool tool,
  }) => PluginMessagePart.tool(
    id: "${tool.canonicalId}-tool",
    sessionID: sessionId,
    messageID: tool.canonicalId,
    tool: tool.tool,
    state: PluginToolState(
      status: tool.status,
      title: tool.title,
      output: tool.output,
      error: tool.status == PluginToolStatus.error ? tool.output : null,
      attachments: tool.attachments,
    ),
  );
}
