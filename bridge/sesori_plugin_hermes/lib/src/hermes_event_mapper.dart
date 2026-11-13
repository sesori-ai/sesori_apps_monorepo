import "package:acp_plugin/acp_plugin.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "hermes_turn_failure_copy.dart";

/// Hermes's event mapper: the standard ACP mapping from [AcpEventMapper], plus
/// Hermes's notices for a failed turn, without its live-only queue
/// acknowledgement (see [map]).
///
/// Live, Hermes sends a failure's explanation as its ordinary final response,
/// so on the wire the notice looks like a reply, and then fails
/// `session/prompt` with `admitted_turn_failed`
/// (`acp_adapter/gateway_server.py`). Its own history saves a fixed closing
/// row instead, which replays as a reply too. Both are recognized by their
/// text and shown as error notices; the shared plugin adds no second notice
/// for the failed prompt, and the bridge's history store keeps one notice per
/// failed turn.
class HermesEventMapper({
  required super.launchDirectory,
  required super.pluginId,
  required super.configurationTracker,
  required super.childSessions,
}) extends AcpEventMapper {
  /// Drops the message id from a live failure-notice chunk.
  ///
  /// The shared mapper reads only id-less chunks as halt notices, because an
  /// identified message may still grow. Hermes sends this notice as its whole,
  /// unstreamed final response under a fresh message id and closes that id
  /// straight away (`acp_adapter/server.py::_finish_turn`), so nothing can
  /// join it and the id carries no grouping.
  ///
  /// Hermes closes the reason with its generic saved row as a last paragraph
  /// (`gateway/run_turn_persistence.py::_hmwa_add_failed_turn_notice`). The
  /// history store drops that same-kind row from the notice on reload, so it
  /// is dropped live too and the notice reads the same before and after.
  ///
  /// Live and on replay, the notice's inline code spans are unwrapped, because
  /// an error notice shows as plain text (see [withoutInlineCodeMarkers]).
  @override
  Map<String, dynamic> normalizeSessionUpdate({required Map<String, dynamic> params}) {
    final update = params["update"];
    if (update is! Map || update["sessionUpdate"] != "agent_message_chunk") return params;
    final content = update["content"];
    if (content is! Map || content["type"] != "text") return params;
    final text = content["text"];
    if (text is! String || classifyHaltNotice(text: text) == null) return params;
    final live = update.containsKey("messageId");
    final notice = live ? withoutTrailingFailedTurnRow(text: text) : text;
    return {
      ...params,
      "update": Map<String, dynamic>.of(update.cast<String, dynamic>())
        ..remove("messageId")
        ..["content"] = {...content, "text": withoutInlineCodeMarkers(notice: notice)},
    };
  }

  /// Drops Hermes's "Queued for the next turn. (N queued)" acknowledgement.
  ///
  /// Hermes sends it, live only, for `/queue <text>` and for a prompt it
  /// queues behind a running turn (`acp_adapter/commands.py::_cmd_queue`,
  /// `acp_adapter/server.py::_claim_turn_or_queue`), then runs the text as a
  /// turn of its own. Its history records neither the acknowledgement nor the
  /// `/queue` line, so after a reload the row stayed beside the replay and,
  /// standing between the run's card and its answer, kept the live answer
  /// from matching its replayed copy. The card already shows the run.
  @override
  List<BridgeSseEvent> map(AcpNotification notification) {
    if (notification.params["update"]
        case {
          "sessionUpdate": "agent_message_chunk",
          "content": {"type": "text", "text": final String text},
        }
        when notification.method == AcpMethods.sessionUpdate && _queuedAcknowledgement.hasMatch(text)) {
      return const [];
    }
    return super.map(notification);
  }

  static final RegExp _queuedAcknowledgement = RegExp(r"^Queued for the next turn\. \(\d+ queued\)$");

  // The shared mapper keeps Hermes's exact wording as the shown message. The
  // error name is the notice's kind: the bridge keeps one notice per failed
  // turn and adds a replayed wording to the live one only when the kinds
  // differ. Hermes's generic saved row stands in for the live reason, so it
  // shares the live notices' kind, and so does the content-refused row, which
  // stands in for the live content-policy reason. The partial-turn row warns
  // that actions may already have run, which the live reason does not say.
  @override
  AcpHaltNotice? classifyHaltNotice({required String text}) {
    if (isHermesPartialTurnRow(text: text)) return const AcpHaltNotice(errorName: "hermes_partial_turn");
    if (isHermesFailedTurnRow(text: text) ||
        isHermesContentRefusedRow(text: text) ||
        isHermesTurnFailureNotice(text: text)) {
      return const AcpHaltNotice(errorName: _failedTurnKind);
    }
    return null;
  }

  /// Hermes sends no explanation when the model had already streamed part of
  /// its reply, so the failed prompt is the only sign. It is shown in the words
  /// of the row Hermes saves for the turn, as the same kind of notice, so a
  /// reload keeps one notice.
  @override
  BridgeSseMessageUpdated mapPromptError({required String sessionId, required String message}) {
    if (message != "admitted_turn_failed") return super.mapPromptError(sessionId: sessionId, message: message);
    return promptErrorEvent(sessionId: sessionId, errorName: _failedTurnKind, message: hermesFailedTurnRow);
  }

  static const String _failedTurnKind = "hermes_failed_turn";
}
