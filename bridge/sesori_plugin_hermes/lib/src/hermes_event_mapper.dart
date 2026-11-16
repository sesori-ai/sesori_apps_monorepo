import "package:acp_plugin/acp_plugin.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "hermes_turn_failure_copy.dart";

/// Hermes's event mapper: the standard ACP mapping from [AcpEventMapper], plus
/// Hermes's notices for a failed turn, without its live-only queue
/// acknowledgement and with its `/compress` reply as a compaction row (see
/// [map]).
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
  required final ServerClock clock,
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
  ///
  /// Hermes sends command responses without a `messageId` and every model
  /// reply with one, so a reply with the same words stays.
  ///
  /// Shows Hermes's `/compress` reply as the compaction row
  /// (`acp_adapter/commands.py::_cmd_compress`, verified v0.21.5). Hermes's
  /// history keeps no record of a `/compress`, so the row is live only.
  @override
  List<BridgeSseEvent> map(AcpNotification notification) {
    if (notification.params
        case {
          "sessionId": final String sessionId,
          "update":
              {
                "sessionUpdate": "agent_message_chunk",
                "content": {"type": "text", "text": final String text},
              } &&
              final Map<Object?, Object?> update,
        }
        when notification.method == AcpMethods.sessionUpdate && !update.containsKey("messageId")) {
      if (_queuedAcknowledgement.hasMatch(text)) return const [];
      if (_compressionState(text: text) case final PluginCompactionState state) {
        return _compactionRow(sessionId: sessionId, state: state);
      }
    }
    return super.map(notification);
  }

  static final RegExp _queuedAcknowledgement = RegExp(r"^Queued for the next turn\. \(\d+ queued\)$");
  static final RegExp _compressed = RegExp(r"^Context compressed: \d+ -> \d+ messages\n~([\d,]+) -> ~([\d,]+) tokens$");

  static PluginCompactionState? _compressionState({required String text}) {
    if (text == "Nothing to compress yet." || text == "Nothing to compress — conversation is empty.") {
      return const .failed(reason: .nothingToCompact);
    }
    final match = _compressed.firstMatch(text);
    if (match?.groups([1, 2]) case [final String before, final String after]) {
      int tokens({required String digits}) => int.parse(digits.replaceAll(",", ""));
      final freed = tokens(digits: before) - tokens(digits: after);
      // Hermes estimates both sizes, and its estimate can rise.
      return .completed(summary: null, freedTokens: freed > 0 ? freed : null, trigger: .manual);
    }
    return null;
  }

  /// One agent message stamped when the reply arrived, holding one part.
  List<BridgeSseEvent> _compactionRow({required String sessionId, required PluginCompactionState state}) {
    final createdAtMs = clock.now().millisecondsSinceEpoch;
    final messageId = "$sessionId-compaction-live-$createdAtMs";
    return [
      BridgeSseMessageUpdated(
        info: PluginMessage.assistant(
          id: messageId,
          sessionID: sessionId,
          agent: pluginId,
          modelID: null,
          providerID: null,
          variant: null,
          sender: PluginMessageSender.agent,
          time: PluginMessageTime(created: createdAtMs, completed: null),
        ),
      ),
      BridgeSseMessagePartUpdated(
        part: PluginMessagePart.compaction(
          id: "$messageId-part",
          sessionID: sessionId,
          messageID: messageId,
          compactionState: state,
        ),
      ),
    ];
  }

  // The shared mapper keeps Hermes's exact wording as the shown message. The
  // error name is the notice's kind: the bridge keeps one notice per failed
  // turn and adds a replayed wording to the live one only when the kinds
  // differ. Hermes's generic saved row stands in for the live reason, so it
  // shares the live notices' kind, and so does the content-refused row, which
  // stands in for the live content-policy reason. The partial-turn row warns
  // that actions may already have run, which the live reason does not say.
  @override
  AcpHaltNotice? classifyHaltNotice({required String text}) {
    if (isHermesPartialTurnRow(text: text)) {
      return const AcpHaltNotice(errorName: "hermes_partial_turn", kind: PluginErrorKind.failure);
    }
    if (isHermesFailedTurnRow(text: text) ||
        isHermesContentRefusedRow(text: text) ||
        isHermesTurnFailureNotice(text: text)) {
      return const AcpHaltNotice(errorName: _failedTurnKind, kind: PluginErrorKind.failure);
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
