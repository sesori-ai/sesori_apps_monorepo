import "package:acp_plugin/acp_plugin.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "../../api/models/deepseek_protocol_dto.dart";

/// Pure projection of DeepSeek's sub-agent protocol into shared child and tile
/// vocabulary. Live and replay paths share the same terminal-state policy.
class const DeepSeekSubagentMapper({required final String agentId}) {
  AcpChildSpawn mapStarted({required DeepSeekSubagentStartedDto notification}) => AcpChildSpawn(
    childSessionId: notification.childSessionId,
    description: notification.label,
    agent: agentId,
    prompt: notification.prompt,
    isBackground: notification.mode == DeepSeekSubagentMode.background,
  );

  PluginToolState mapState({
    required DeepSeekSubagentStopReason? stopReason,
    required String? summary,
  }) {
    if (stopReason == null) {
      return const PluginToolState(
        status: PluginToolStatus.running,
        title: null,
        output: null,
        error: null,
        attachments: [],
      );
    }
    return switch (stopReason) {
      DeepSeekSubagentStopReason.completed => PluginToolState(
        status: PluginToolStatus.completed,
        title: null,
        output: summary,
        error: null,
        attachments: const [],
      ),
      DeepSeekSubagentStopReason.aborted => const PluginToolState(
        status: PluginToolStatus.cancelled,
        title: null,
        output: null,
        error: null,
        attachments: [],
      ),
      DeepSeekSubagentStopReason.error ||
      DeepSeekSubagentStopReason.maxTokens ||
      DeepSeekSubagentStopReason.refusal => PluginToolState(
        status: PluginToolStatus.error,
        title: null,
        output: null,
        error: summary ?? _errorFor(stopReason: stopReason),
        attachments: const [],
      ),
      DeepSeekSubagentStopReason.unknown => throw const FormatException("Unknown DeepSeek sub-agent stop reason"),
    };
  }

  PluginMessagePart mapReplay({
    required PluginMessagePartTool toolPart,
    required DeepSeekSubagentReplayDto replay,
  }) => PluginMessagePart.subtask(
    // Retain the generic ACP tool identity so replay replacement is an upsert,
    // never a second card for the same delegation call.
    id: toolPart.id,
    sessionID: toolPart.sessionID,
    messageID: toolPart.messageID,
    prompt: replay.prompt,
    description: replay.label,
    agent: agentId,
    taskState: mapState(
      stopReason: replay.ended?.stopReason,
      summary: replay.ended?.summary,
    ),
    childSessionID: replay.childSessionId,
  );

  String _errorFor({required DeepSeekSubagentStopReason stopReason}) => switch (stopReason) {
    DeepSeekSubagentStopReason.error => "DeepSeek sub-agent failed",
    DeepSeekSubagentStopReason.maxTokens => "DeepSeek sub-agent reached its token limit",
    DeepSeekSubagentStopReason.refusal => "DeepSeek sub-agent declined the task",
    DeepSeekSubagentStopReason.completed ||
    DeepSeekSubagentStopReason.aborted ||
    DeepSeekSubagentStopReason.unknown => throw StateError("DeepSeek sub-agent stop reason is not an error"),
  };
}
