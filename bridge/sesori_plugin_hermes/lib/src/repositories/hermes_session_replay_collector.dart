import "package:acp_plugin/acp_plugin.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "../models/hermes_replay_update_dto.dart";

/// Hermes's replay: the standard ACP history, with each compaction summary
/// shown as a compaction row.
///
/// Hermes compacts a session in place and sends no live sign of an automatic
/// compaction (verified v0.21.5). Its history then replays the summary in
/// place of the compacted turns, as an agent chunk marked
/// `_meta.hermes.compactionSummary` (`acp_adapter/server.py`). The chunk is
/// written for the model, so the row keeps only the summary body.
class HermesSessionReplayCollector({
  required final String sessionId,
  required final AcpReplayCollector standardCollector,
}) implements AcpSessionReplayCollector {
  var _summaries = 0;

  @override
  void consumeNotification({required AcpNotification notification}) {
    final text = _compactionSummaryText(notification: notification);
    if (text == null) {
      standardCollector.consumeNotification(notification: notification);
      return;
    }
    // The replay's position names the row, so every reload keeps its id.
    final messageId = "$sessionId-compaction-${_summaries++}";
    standardCollector.upsertAssistantMessage(
      messageId: messageId,
      parts: [
        PluginMessagePart.compaction(
          id: "$messageId-part",
          sessionID: sessionId,
          messageID: messageId,
          compactionState: .completed(summary: summaryBody(text: text), freedTokens: null, trigger: null),
        ),
      ],
      time: null,
    );
  }

  static String? _compactionSummaryText({required AcpNotification notification}) {
    final update = notification.params["update"];
    // Only an agent chunk can be a summary; other updates carry other content.
    if (notification.method != AcpMethods.sessionUpdate ||
        update is! Map<String, dynamic> ||
        update["sessionUpdate"] != "agent_message_chunk") {
      return null;
    }
    final HermesReplayUpdateDto dto;
    try {
      dto = HermesReplayUpdateDto.fromJson(update);
    } on Object catch (error, stackTrace) {
      Log.w("[hermes] read a replayed agent chunk without its compaction marker", error, stackTrace);
      return null;
    }
    if (!(dto.meta?.hermes?.compactionSummary ?? false) || dto.content?.type != "text") return null;
    return dto.content?.text;
  }

  @override
  List<PluginMessageWithParts> buildWithAssistantSelection({
    required String? modelId,
    required String? providerId,
    required String? variant,
  }) => standardCollector.buildWithAssistantSelection(modelId: modelId, providerId: providerId, variant: variant);

  /// The summary without Hermes's one-line instructions to the model before it
  /// and its end marker after it (`agent/context_compressor.py::SUMMARY_PREFIX`,
  /// `_SUMMARY_END_MARKER`).
  static String? summaryBody({required String text}) {
    var body = text;
    if (body.startsWith("[CONTEXT COMPACTION")) {
      final lineEnd = body.indexOf("\n");
      body = lineEnd < 0 ? "" : body.substring(lineEnd + 1);
    }
    final end = body.indexOf("--- END OF CONTEXT SUMMARY");
    if (end >= 0) body = body.substring(0, end);
    body = body.trim();
    return body.isEmpty ? null : body;
  }
}
