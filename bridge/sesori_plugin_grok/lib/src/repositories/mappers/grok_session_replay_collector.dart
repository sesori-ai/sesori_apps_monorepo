import "package:acp_plugin/acp_plugin.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "../../api/models/grok_session_notification_dto.dart";
import "../models/grok_session_replay_context.dart";
import "grok_subagent_status_mapping.dart";

/// Stateful replay-local Grok lifecycle collector. Standard ACP reconstruction
/// stays in one collector, preserving its identity allocator across inserted tiles.
class GrokSessionReplayCollector({
  required final String sessionId,
  required final AcpReplayCollector standardCollector,
  required final GrokSessionReplayContext context,
}) implements AcpSessionReplayCollector {
  final Map<String, _GrokReplayTile> _tilesByChild = {};
  _GrokReplayCompaction? _runningAuto;
  ({int? freedTokens, int? completedAtMs})? _pendingManual;

  @override
  void consumeNotification({required AcpNotification notification}) {
    standardCollector.consumeNotification(notification: notification);
    if (notification.method != GrokSessionProtocol.updateMethod &&
        notification.method != GrokSessionProtocol.notificationMethod) {
      return;
    }
    final GrokSessionNotificationDto dto;
    try {
      dto = GrokSessionNotificationDto.fromJson(notification.params);
    } on Object catch (error, stackTrace) {
      Log.w("[grok] ignored malformed replay session notification", error, stackTrace);
      return;
    }
    if (dto.sessionId != sessionId) return;
    switch (dto.update) {
      case GrokSubagentSpawned(
        :final childSessionId,
        :final subagentType,
        :final description,
      ):
        _spawn(
          childSessionId: childSessionId,
          description: description,
          agent: subagentType ?? GrokSessionProtocol.defaultSubagentType,
        );
      case GrokSubagentFinished(
        :final childSessionId,
        :final status,
        :final output,
        :final error,
      ):
        _finish(
          childSessionId: childSessionId,
          status: status.toPluginToolStatus(),
          output: output,
          error: error,
        );
      case GrokAutoCompactStarted():
        final eventId = dto.meta?.eventId;
        if (eventId == null) return;
        final compaction = (
          messageId: GrokSessionProtocol.compactionMessageId(sessionId: sessionId, key: eventId),
          createdAtMs: dto.meta?.agentTimestampMs,
        );
        _runningAuto = compaction;
        _upsertCompaction(compaction: compaction, state: const .running(summary: null));
      case GrokAutoCompactCompleted(:final tokensBefore, :final tokensAfter):
        final freedTokens = GrokSessionProtocol.freedTokens(tokensBefore: tokensBefore, tokensAfter: tokensAfter);
        final compaction = _runningAuto;
        _runningAuto = null;
        if (compaction == null) {
          // A manual `/compact` has no start, and replay sends its completion
          // before the `/compact` itself, so its row waits for the turn's end.
          _pendingManual = (freedTokens: freedTokens, completedAtMs: dto.meta?.agentTimestampMs);
          return;
        }
        _upsertCompaction(
          compaction: compaction,
          state: .completed(summary: null, freedTokens: freedTokens, trigger: .auto),
        );
      case GrokAutoCompactFailed():
        final compaction = _runningAuto;
        _runningAuto = null;
        if (compaction != null) _upsertCompaction(compaction: compaction, state: const .failed(reason: null));
      case GrokTurnCompleted(:final promptId):
        // A stopped compaction has no end, so its row stays running for the
        // bridge's sweep, as it did live.
        _runningAuto = null;
        final manual = _pendingManual;
        _pendingManual = null;
        if (manual == null || promptId == null) return;
        _upsertCompaction(
          compaction: (
            messageId: GrokSessionProtocol.compactionMessageId(sessionId: sessionId, key: promptId),
            createdAtMs: manual.completedAtMs,
          ),
          state: .completed(summary: null, freedTokens: manual.freedTokens, trigger: .manual),
        );
      case GrokSubagentProgress() || GrokSubagentUpdateUnknown():
        break;
    }
  }

  @override
  List<PluginMessageWithParts> buildWithAssistantSelection({
    required String? modelId,
    required String? providerId,
    required String? variant,
  }) => standardCollector.buildWithAssistantSelection(
    modelId: modelId,
    providerId: providerId,
    variant: variant,
  );

  /// The row the live mapper showed, under the same message id.
  void _upsertCompaction({required _GrokReplayCompaction compaction, required PluginCompactionState state}) {
    standardCollector.upsertAssistantMessage(
      messageId: compaction.messageId,
      parts: [
        PluginMessagePart.compaction(
          id: "${compaction.messageId}-part",
          sessionID: sessionId,
          messageID: compaction.messageId,
          compactionState: state,
        ),
      ],
      time: switch (compaction.createdAtMs) {
        final int createdAtMs => PluginMessageTime(created: createdAtMs, completed: null),
        null => null,
      },
    );
  }

  void _spawn({
    required String childSessionId,
    required String? description,
    required String agent,
  }) {
    if (_tilesByChild.containsKey(childSessionId)) return;
    final prompt = context.promptFor(childSessionId: childSessionId);
    final usefulDescription = _usefulText(description);
    if (prompt == null || usefulDescription == null || childSessionId.isEmpty) return;
    final messageId = "$sessionId-subagent-$childSessionId";
    final tile = _GrokReplayTile(
      childSessionId: childSessionId,
      messageId: messageId,
      partId: "$messageId-subtask",
      prompt: prompt,
      description: usefulDescription,
      agent: agent,
    );
    _tilesByChild[childSessionId] = tile;
    _upsert(tile: tile);
  }

  void _finish({
    required String childSessionId,
    required PluginToolStatus status,
    required String? output,
    required String? error,
  }) {
    final tile = _tilesByChild[childSessionId];
    if (tile == null || tile.status.isTerminal) return;
    tile
      ..status = status
      ..output = status == PluginToolStatus.completed ? _bounded(output) : null
      ..error = status == PluginToolStatus.error ? _bounded(error) : null;
    _upsert(tile: tile);
  }

  void _upsert({required _GrokReplayTile tile}) {
    standardCollector.upsertAssistantMessage(
      messageId: tile.messageId,
      parts: [
        PluginMessagePart.subtask(
          id: tile.partId,
          sessionID: sessionId,
          messageID: tile.messageId,
          prompt: tile.prompt,
          description: tile.description,
          agent: tile.agent,
          taskState: PluginToolState(
            status: tile.status,
            title: null,
            shellCommand: null,
            output: tile.output,
            error: tile.error,
            attachments: const [],
          ),
          childSessionID: tile.childSessionId,
        ),
      ],
      time: null,
    );
  }

  static String? _usefulText(String? value) {
    final normalized = value?.trim();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }

  static String? _bounded(String? value) =>
      value == null || value.isEmpty ? null : String.fromCharCodes(value.runes.take(maxToolOutputLength));
}

typedef _GrokReplayCompaction = ({String messageId, int? createdAtMs});

final class _GrokReplayTile({
  required final String childSessionId,
  required final String messageId,
  required final String partId,
  required final String prompt,
  required final String description,
  required final String agent,
}) {
  PluginToolStatus status = PluginToolStatus.running;
  String? output;
  String? error;
}
