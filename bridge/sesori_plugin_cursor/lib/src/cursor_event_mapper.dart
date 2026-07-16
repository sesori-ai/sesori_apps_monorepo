import "package:acp_plugin/acp_plugin.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

/// Cursor's event mapper: the standard ACP `session/update` handling from
/// [AcpEventMapper] plus Cursor's `cursor/*` notification extensions.
class CursorEventMapper extends AcpEventMapper {
  CursorEventMapper({required super.launchDirectory, required super.pluginId}) : super(agentId: pluginId);

  @override
  List<BridgeSseEvent> mapExtension(AcpNotification notification) {
    switch (notification.method) {
      case "cursor/update_todos":
        final sessionId = notification.params["sessionId"] as String?;
        if (sessionId == null || sessionId.isEmpty) return const [];
        return [BridgeSseTodoUpdated(sessionID: sessionId)];
    }
    // cursor/task, cursor/generate_image and other extension notifications
    // have no sesori analog — dropped.
    return const [];
  }

  @override
  AcpHaltNotice? classifyHaltNotice({required String text}) {
    if (_isGateNotice(text)) {
      // Preserve cursor-agent's own wording (trimmed) as the shown message.
      return AcpHaltNotice(errorName: "cursor_gate", message: text.trim());
    }
    return null;
  }

  /// cursor-agent account/plan/settings gate notices. When the selected model
  /// or action isn't permitted on the Cursor account, cursor-agent ends the
  /// turn normally (`stopReason: end_turn`) and streams one of these as an
  /// ordinary `agent_message_chunk` — on the wire it is indistinguishable from
  /// real output, so it is recognized here by exact (normalized) text.
  ///
  /// Add a phrase only with a captured wire trace of cursor-agent emitting it;
  /// a reworded or localized gate simply falls through to plain assistant text
  /// (the pre-existing behavior — no regression).
  static const Set<String> _gateNoticePhrases = {
    "check your settings to continue",
  };

  static bool _isGateNotice(String text) => _gateNoticePhrases.contains(_normalize(text));

  /// Normalizes a notice for matching against [_gateNoticePhrases]: collapses
  /// whitespace, lowercases, and strips surrounding punctuation/emoji so the
  /// leading newlines, case, or decoration cursor-agent varies do not defeat
  /// the match — while still requiring the whole message to BE the phrase, so
  /// ordinary prose that merely mentions it is never misclassified. Letters and
  /// digits of any script are content, never strippable decoration: a message
  /// carrying words beyond the phrase must not collapse into a gate match.
  static String _normalize(String text) {
    final collapsed = text.replaceAll(RegExp(r"\s+"), " ").trim().toLowerCase();
    return collapsed.replaceAll(
      RegExp(r"^[^\p{L}\p{N}]+|[^\p{L}\p{N}]+$", unicode: true),
      "",
    );
  }
}
