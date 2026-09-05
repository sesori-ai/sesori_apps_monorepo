import "package:acp_plugin/acp_plugin.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "../../api/models/deepseek_protocol_dto.dart";

/// Pure projection of DeepSeek's sub-agent protocol into shared child and tile
/// vocabulary, including terminal outcomes and bounded presentation output.
class const DeepSeekSubagentMapper({required final String agentId}) {
  AcpChildSpawn mapStarted({required DeepSeekSubagentStartedDto notification}) => AcpChildSpawn(
    childSessionId: notification.childSessionId,
    description: notification.label,
    agent: agentId,
    prompt: notification.prompt,
    isBackground: notification.mode == DeepSeekSubagentMode.background,
  );

  PluginToolState mapState({
    required DeepSeekSubagentStopReason stopReason,
    required String? summary,
  }) {
    final boundedSummary = _bounded(value: summary);
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

  PluginMessagePartSubtask mapReplay({
    required PluginMessagePartTool toolPart,
    required DeepSeekSubagentReplayDto replay,
  }) {
    final childSessionId = replay.childSessionId;
    final messageId = childSessionId == null ? toolPart.messageID : "${toolPart.sessionID}-subagent-$childSessionId";
    return PluginMessagePartSubtask(
      id: childSessionId == null ? toolPart.id : "$messageId-subtask",
      sessionID: toolPart.sessionID,
      messageID: messageId,
      prompt: replay.prompt,
      description: replay.label,
      agent: agentId,
      taskState: switch (replay.ended) {
        null => const PluginToolState(
          status: PluginToolStatus.running,
          title: null,
          output: null,
          error: null,
          attachments: [],
        ),
        final ended => mapState(stopReason: ended.stopReason, summary: ended.summary),
      },
      childSessionID: childSessionId,
    );
  }

  /// Splits contiguous part runs without changing their order. Child-linked
  /// identities match live tiles; the first ordinary run keeps its source ID,
  /// and later ordinary runs get deterministic message and part IDs for storage.
  List<PluginMessageWithParts> alignReplayChildIdentities({required List<PluginMessageWithParts> messages}) {
    final aligned = <PluginMessageWithParts>[];
    for (final message in messages) {
      if (message.parts.isEmpty) {
        aligned.add(message);
        continue;
      }
      var runStart = 0;
      var parentRunOrdinal = 0;
      for (var end = 1; end <= message.parts.length; end++) {
        final first = message.parts[runStart];
        if (end < message.parts.length &&
            message.parts[end].messageID == first.messageID &&
            message.parts[end].sessionID == first.sessionID) {
          continue;
        }
        final isParentRun = first.messageID == message.info.id && first.sessionID == message.info.sessionID;
        if (isParentRun) parentRunOrdinal++;
        final suffix = isParentRun && parentRunOrdinal > 1 ? "-deepseek-replay-run-$parentRunOrdinal" : null;
        final messageId = suffix == null ? first.messageID : "${first.messageID}$suffix";
        aligned.add(
          PluginMessageWithParts(
            info: message.info.copyWith(id: messageId, sessionID: first.sessionID),
            parts: [
              for (final part in message.parts.sublist(runStart, end))
                suffix == null ? part : part.copyWith(id: "${part.id}$suffix", messageID: messageId),
            ],
          ),
        );
        runStart = end;
      }
    }
    return aligned;
  }

  String? _bounded({required String? value}) =>
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
