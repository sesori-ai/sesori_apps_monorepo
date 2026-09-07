import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "../models/codex_projected_tool.dart";
import "../models/codex_thread_record.dart";
import "codex_sub_agent_name_mapper.dart";

/// One part projection for live tool upserts and saved transcript replay.
class const CodexToolPartMapper() {
  PluginMessagePart map({
    required String sessionId,
    required CodexProjectedTool tool,
    required List<CodexThreadRecord> children,
  }) {
    final state = PluginToolState(
      status: tool.status,
      title: tool.title,
      output: tool.output,
      error: tool.status == PluginToolStatus.error ? tool.output : null,
      attachments: tool.attachments,
    );
    switch (tool.presentation) {
      case CodexOrdinaryToolPresentation():
        return PluginMessagePart.tool(
          id: "${tool.canonicalId}-tool",
          sessionID: sessionId,
          messageID: tool.canonicalId,
          tool: tool.tool,
          state: state,
        );
      case CodexSubtaskPresentation(:final taskName, :final prompt, :final agent, :final childSessionId):
        CodexThreadRecord? child;
        for (final candidate in children) {
          if (childSessionId != null
              ? candidate.id == childSessionId
              : taskName != null &&
                    candidate.agentPath != null &&
                    (candidate.agentPath == taskName || candidate.agentPath!.split("/").last == taskName)) {
            child = candidate;
            break;
          }
        }
        final title =
            const CodexSubAgentNameMapper().map(
              name: child?.name,
              nickname: child?.agentNickname,
              agentPath: child?.agentPath ?? taskName,
            ) ??
            "Subtask";
        final targetId = childSessionId ?? child?.id;
        return PluginMessagePart.subtask(
          id: "${tool.canonicalId}-tool",
          sessionID: sessionId,
          messageID: tool.canonicalId,
          description: title,
          prompt: prompt ?? title,
          agent: agent,
          childSessionID: targetId,
          // A completed spawn only launched the child. The shared tile follows
          // that child's session status, including work after the parent ends.
          taskState: targetId == null ? state : null,
        );
    }
  }
}
