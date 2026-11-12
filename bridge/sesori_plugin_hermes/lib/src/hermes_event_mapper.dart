import "package:acp_plugin/acp_plugin.dart";

import "hermes_turn_failure_copy.dart";

/// Hermes's event mapper: the standard ACP mapping from [AcpEventMapper], plus
/// Hermes's notices for a failed turn.
///
/// Live, Hermes reports a failure as its ordinary final response and ends the
/// turn with `stopReason: end_turn`, so on the wire the notice looks like a
/// reply. Its own history saves a fixed closing row instead, which replays as
/// a reply too. Both are recognized by their text and shown as error notices;
/// the bridge's history store keeps one notice per failed turn.
class HermesEventMapper({
  required super.launchDirectory,
  required super.pluginId,
  required super.configurationTracker,
  required super.childSessions,
}) extends AcpEventMapper {
  /// Drops the message id from a failure-notice chunk.
  ///
  /// The shared mapper reads only id-less chunks as halt notices, because an
  /// identified message may still grow. Hermes sends this notice as its whole,
  /// unstreamed final response under a fresh message id and closes that id
  /// straight away (`acp_adapter/server.py::_finish_turn`), so nothing can
  /// join it and the id carries no grouping.
  @override
  Map<String, dynamic> normalizeSessionUpdate({required Map<String, dynamic> params}) {
    final update = params["update"];
    if (update is! Map || update["sessionUpdate"] != "agent_message_chunk" || !update.containsKey("messageId")) {
      return params;
    }
    final content = update["content"];
    if (content is! Map || content["type"] != "text") return params;
    final text = content["text"];
    if (text is! String || classifyHaltNotice(text: text) == null) return params;
    return {
      ...params,
      "update": Map<String, dynamic>.of(update.cast<String, dynamic>())..remove("messageId"),
    };
  }

  // The shared mapper keeps Hermes's exact wording as the shown message. The
  // error name is the notice's kind: the bridge keeps one notice per failed
  // turn and adds a replayed wording to the live one only when the kinds
  // differ. Hermes's generic saved row stands in for the live reason, so it
  // shares the live notices' kind; the partial-turn row warns that actions
  // may already have run, which the live reason does not say.
  @override
  AcpHaltNotice? classifyHaltNotice({required String text}) {
    if (isHermesPartialTurnRow(text: text)) return const AcpHaltNotice(errorName: "hermes_partial_turn");
    if (isHermesFailedTurnRow(text: text) || isHermesTurnFailureNotice(text: text)) {
      return const AcpHaltNotice(errorName: "hermes_failed_turn");
    }
    return null;
  }
}
