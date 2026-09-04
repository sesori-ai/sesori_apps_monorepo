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
    final boundedSummary = _bounded(summary);
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
        output: boundedSummary,
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
        error: boundedSummary ?? _errorFor(stopReason: stopReason),
        attachments: const [],
      ),
      DeepSeekSubagentStopReason.unknown => throw const FormatException("Unknown DeepSeek sub-agent stop reason"),
    };
  }

  PluginMessagePart mapReplay({
    required PluginMessagePartTool toolPart,
    required DeepSeekSubagentReplayDto replay,
  }) {
    final childSessionId = replay.childSessionId;
    final messageId = childSessionId == null ? toolPart.messageID : "${toolPart.sessionID}-subagent-$childSessionId";
    return PluginMessagePart.subtask(
      id: childSessionId == null ? toolPart.id : "$messageId-subtask",
      sessionID: toolPart.sessionID,
      messageID: messageId,
      prompt: replay.prompt,
      description: replay.label,
      agent: agentId,
      taskState: mapState(
        stopReason: replay.ended?.stopReason,
        summary: replay.ended?.summary,
      ),
      childSessionID: childSessionId,
    );
  }

  /// Separates a child-linked replay replacement from the generic ACP message
  /// envelope that originally owned its tool call. The resulting message and
  /// part identities are exactly those used by the live child tracker, so a
  /// later terminal lifecycle event updates the imported running tile.
  List<PluginMessageWithParts> alignReplayChildIdentities({required List<PluginMessageWithParts> messages}) {
    final aligned = <PluginMessageWithParts>[];
    for (final message in messages) {
      final originalParts = <PluginMessagePart>[];
      final childParts = <PluginMessagePart>[];
      for (final part in message.parts) {
        (part is PluginMessagePartSubtask && part.messageID != message.info.id ? childParts : originalParts).add(
          part,
        );
      }
      if (originalParts.isNotEmpty) {
        aligned.add(PluginMessageWithParts(info: message.info, parts: originalParts));
      }
      for (final part in childParts) {
        aligned.add(
          PluginMessageWithParts(
            info: message.info.copyWith(id: part.messageID),
            parts: [part],
          ),
        );
      }
    }
    return aligned;
  }

  String? _bounded(String? value) =>
      value == null || value.isEmpty ? null : String.fromCharCodes(value.runes.take(maxToolOutputLength));

  String _errorFor({required DeepSeekSubagentStopReason stopReason}) => switch (stopReason) {
    DeepSeekSubagentStopReason.error => "DeepSeek sub-agent failed",
    DeepSeekSubagentStopReason.maxTokens => "DeepSeek sub-agent reached its token limit",
    DeepSeekSubagentStopReason.refusal => "DeepSeek sub-agent declined the task",
    DeepSeekSubagentStopReason.completed ||
    DeepSeekSubagentStopReason.aborted ||
    DeepSeekSubagentStopReason.unknown => throw StateError("DeepSeek sub-agent stop reason is not an error"),
  };
}
