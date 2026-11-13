import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "../models/codex_projected_tool.dart";

/// One tool projection for live upserts and saved transcript replay.
class const CodexToolPartMapper() {
  PluginMessagePart map({
    required String sessionId,
    required CodexProjectedTool tool,
  }) => PluginMessagePart.tool(
    id: "${tool.canonicalId}-tool",
    sessionID: sessionId,
    messageID: tool.canonicalId,
    tool: switch (tool.presentation) {
      CodexOrdinaryToolPresentation() => tool.tool,
      CodexWaitAgentToolPresentation(:final agentCount) => _waitAgentLabel(
        agentCount: agentCount,
        status: tool.status,
      ),
    },
    state: PluginToolState(
      status: tool.status,
      title: tool.title,
      shellCommand: tool.shellCommand,
      output: tool.output,
      error: tool.status == PluginToolStatus.error ? tool.output : null,
      attachments: tool.attachments,
    ),
  );

  /// The row's sentence: present tense while the wait runs, past once it ends.
  static String _waitAgentLabel({required int? agentCount, required PluginToolStatus status}) {
    final verb = status.isTerminal ? "Waited" : "Waiting";
    return switch (agentCount) {
      null => "$verb for sub-agents",
      1 => "$verb for 1 sub-agent",
      final count => "$verb for $count sub-agents",
    };
  }
}
