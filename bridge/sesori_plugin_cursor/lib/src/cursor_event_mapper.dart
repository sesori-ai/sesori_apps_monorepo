import "package:acp_plugin/acp_plugin.dart";
import "package:path/path.dart" as p;
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "repositories/cursor_generated_image_reader.dart";

/// Cursor's event mapper: the standard ACP `session/update` handling from
/// [AcpEventMapper] plus Cursor's `cursor/*` notification extensions.
///
/// cursor-agent sends some extensions (`cursor/generate_image`,
/// `cursor/update_todos`) as `extMethod` JSON-RPC *requests* even though it
/// treats them as fire-and-forget; the approval registry acks and re-injects
/// those into the notification pipeline (see
/// [AcpApprovalRegistry.fireAndForgetExtensionMethods]), so this mapper is the
/// single handling site for both wire shapes.
class CursorEventMapper({
    required super.launchDirectory,
    required super.pluginId,
    required super.configurationTracker,
    required super.contentMapper,
    required CursorGeneratedImageReader generatedImageReader,
    required String? Function() activeSessionResolver,
  }) extends AcpEventMapper {
  this : _generatedImageReader = generatedImageReader,
       _activeSessionResolver = activeSessionResolver,
       super(agentId: pluginId);

  final CursorGeneratedImageReader _generatedImageReader;

  /// The plugin's active-turn resolver ([AcpPlugin.activeTurnSessionId]) — the
  /// last-resort attribution for Cursor extension payloads that omit
  /// `sessionId` (cursor-agent's extension calls carry only the originating
  /// `toolCallId`, or nothing). The same closure backs the approval registry's
  /// session fallback, so "which session does an unattributed payload belong
  /// to" has exactly one owner: the plugin, which also clears its state when a
  /// session is deleted.
  final String? Function() _activeSessionResolver;

  @override
  List<BridgeSseEvent> mapExtension(AcpNotification notification) {
    switch (notification.method) {
      case "cursor/update_todos":
        final sessionId = _extensionSessionId(notification.params);
        if (sessionId == null) return const [];
        return [BridgeSseTodoUpdated(sessionID: sessionId)];
      case "cursor/generate_image":
        return _mapGenerateImage(notification: notification);
    }
    // cursor/task and other extension notifications have no sesori analog.
    return super.mapExtension(notification);
  }

  List<BridgeSseEvent> _mapGenerateImage({required AcpNotification notification}) {
    final params = notification.params;
    final sessionId = _extensionSessionId(params);
    final path = _pathFromGenerateImageParams(params: params);
    if (sessionId == null || path == null) {
      // The registry already acked the request, so this drop is the last place
      // a lost image can be observed. Local logs keep the path (sanctioned
      // diagnostic context); only the transport stays basename-only.
      Log.w(
        "[cursor] ${notification.method} dropped: "
        "${sessionId == null ? "no resolvable session" : "session $sessionId"}, "
        "${path == null ? "no source path" : "path ${path.trim()}"}",
      );
      return const [];
    }

    final blocks = _generatedImageReader.read(path: path);
    if (blocks.isEmpty) return const [];

    final rawMessageId = params["messageId"];
    return appendAssistantImageBlocks(
      sessionId: sessionId,
      messageId: rawMessageId is String && rawMessageId.isNotEmpty ? rawMessageId : null,
      blocks: blocks,
    );
  }

  /// The session an extension payload belongs to: its explicit `sessionId`
  /// (trimmed, matching [AcpApprovalRegistry.resolveSessionId]), else the
  /// session owning the originating `toolCallId`, else the plugin's active
  /// turn. Null only when none is available — the caller must drop the payload
  /// (an event stamped with "" is discarded by the client).
  String? _extensionSessionId(Map<String, dynamic> params) {
    final explicit = params["sessionId"];
    if (explicit is String) {
      final trimmed = explicit.trim();
      if (trimmed.isNotEmpty) return trimmed;
    }
    final toolCallId = params["toolCallId"];
    if (toolCallId is String && toolCallId.isNotEmpty) {
      final fromTool = sessionIdForToolCallId(toolCallId: toolCallId);
      if (fromTool != null) return fromTool;
    }
    return _activeSessionResolver();
  }

  /// `filePath` is the live-verified key; `path` has provenance from the
  /// pre-PR wire tests. Only absolute paths are accepted: a relative or bare
  /// value would resolve against the bridge process CWD, not the session's
  /// project, so it must never be opened.
  static String? _pathFromGenerateImageParams({required Map<String, dynamic> params}) {
    for (final key in const ["filePath", "path"]) {
      final value = params[key];
      if (value is! String) continue;
      final trimmed = value.trim();
      if (trimmed.isEmpty) continue;
      if (p.isAbsolute(trimmed)) return trimmed;
      Log.w("[cursor] generate_image rejected non-absolute source path: $trimmed");
    }
    return null;
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
