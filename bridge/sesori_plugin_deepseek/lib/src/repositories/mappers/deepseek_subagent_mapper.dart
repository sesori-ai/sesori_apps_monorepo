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
  /// envelope that originally owned its tool call. Child identities exactly
  /// match the live tracker; the first parent run keeps its source identity and
  /// later runs receive deterministic message and part identities for storage.
  List<PluginMessageWithParts> alignReplayChildIdentities({required List<PluginMessageWithParts> messages}) {
    final aligned = <PluginMessageWithParts>[];
    for (final message in messages) {
      var runParts = <PluginMessagePart>[];
      var runMessageId = message.info.id;
      var runSessionId = message.info.sessionID;
      var parentRunOrdinal = 0;
      for (final part in message.parts) {
        final isChildEnvelope = part is PluginMessagePartSubtask && part.messageID != message.info.id;
        final partMessageId = isChildEnvelope ? part.messageID : message.info.id;
        final partSessionId = isChildEnvelope ? part.sessionID : message.info.sessionID;
        if (runParts.isNotEmpty && (partMessageId != runMessageId || partSessionId != runSessionId)) {
          final isParentRun = runMessageId == message.info.id && runSessionId == message.info.sessionID;
          if (isParentRun) parentRunOrdinal++;
          aligned.add(
            _alignedReplayRun(
              message: message,
              messageId: runMessageId,
              sessionId: runSessionId,
              parts: runParts,
              parentRunOrdinal: isParentRun ? parentRunOrdinal : null,
            ),
          );
          runParts = [];
        }
        runMessageId = partMessageId;
        runSessionId = partSessionId;
        runParts.add(part);
      }
      if (runParts.isNotEmpty) {
        final isParentRun = runMessageId == message.info.id && runSessionId == message.info.sessionID;
        if (isParentRun) parentRunOrdinal++;
        aligned.add(
          _alignedReplayRun(
            message: message,
            messageId: runMessageId,
            sessionId: runSessionId,
            parts: runParts,
            parentRunOrdinal: isParentRun ? parentRunOrdinal : null,
          ),
        );
      }
    }
    return aligned;
  }

  PluginMessageWithParts _alignedReplayRun({
    required PluginMessageWithParts message,
    required String messageId,
    required String sessionId,
    required List<PluginMessagePart> parts,
    required int? parentRunOrdinal,
  }) {
    final identitySuffix = switch (parentRunOrdinal) {
      null || 1 => null,
      final ordinal => "-deepseek-replay-run-$ordinal",
    };
    final alignedMessageId = identitySuffix == null ? messageId : "$messageId$identitySuffix";
    return PluginMessageWithParts(
      info: message.info.copyWith(id: alignedMessageId, sessionID: sessionId),
      parts: [
        for (final part in parts)
          identitySuffix == null
              ? part
              : part.copyWith(
                  id: "${part.id}$identitySuffix",
                  sessionID: sessionId,
                  messageID: alignedMessageId,
                ),
      ],
    );
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
