import "package:acp_plugin/acp_plugin.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "../../api/models/grok_session_notification_dto.dart";
import "../../grok_event_mapper.dart";
import "../models/grok_session_replay_context.dart";
import "grok_subagent_status_mapping.dart";

/// Pure replay-local Grok lifecycle mapper. Standard ACP reconstruction stays
/// in one collector, preserving its identity allocator across inserted tiles.
class GrokSessionReplayMapper({
  required final String sessionId,
  required final AcpReplayCollector standardCollector,
  required final GrokSessionReplayContext context,
}) implements AcpSessionReplayMapper {
  final Map<String, _GrokReplayTile> _tilesByChild = {};

  @override
  void consumeNotification({required AcpNotification notification}) {
    standardCollector.consumeNotification(notification: notification);
    if (notification.method != GrokEventMapper.sessionUpdateMethod &&
        notification.method != GrokEventMapper.sessionNotificationMethod) {
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
          agent: subagentType ?? GrokEventMapper.defaultSubagentType,
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
      case GrokSubagentProgress() || GrokTurnCompleted() || GrokSubagentUpdateUnknown():
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
