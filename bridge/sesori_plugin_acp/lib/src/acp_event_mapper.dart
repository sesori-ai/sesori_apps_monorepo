import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart" show normalizeProjectDirectory;
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart" as shared;

import "acp_content.dart";
import "acp_protocol.dart";
import "acp_stdio_client.dart";

/// Translates ACP `session/update` notifications into bridge-neutral
/// [BridgeSseEvent]s.
///
/// Like the codex mapper, the `info` maps on session/message events MUST be
/// sesori-schema JSON (parseable by `Message.fromJson` / `Session.fromJson`),
/// so we build typed `sesori_shared` models and `.toJson()` them.
///
/// ACP differs from codex's app-server protocol in two ways that shape this
/// mapper:
///  1. There are no `turn/started` / `turn/completed` notifications — the
///     plugin derives busy/idle from the `session/prompt` future, so this
///     mapper does not emit session-status events.
///  2. Streaming chunks (`agent_message_chunk`, …) carry no message id, so we
///     synthesize a stable per-turn id. The plugin calls [beginTurn] before
///     each `session/prompt` to advance the turn counter.
///
/// Harness-specific notifications (e.g. Cursor's `cursor/*`) are routed to
/// [mapExtension], which subclasses override.
class AcpEventMapper {
  AcpEventMapper({required String launchDirectory, required this.agentId})
    : launchDirectory = normalizeProjectDirectory(directory: launchDirectory);

  /// The bridge launch directory (canonicalized) — the fallback project
  /// attribution for sessions whose own directory is not (yet) known. Matches
  /// the canonical project id the bridge derives for the same directory.
  final String launchDirectory;

  /// Agent name stamped on assistant messages (e.g. "cursor").
  final String agentId;

  /// Global fallback model/provider stamped on assistant messages when a
  /// session has no specific model recorded. The plugin sets these once the
  /// model catalog resolves.
  String? currentModelId;
  String? currentProviderId;

  /// Per-session model/provider. ACP's live `*_chunk` notifications carry no
  /// model, so the plugin records the resolved per-session model here (via
  /// [setSessionModel]); without it every streamed message would be stamped
  /// with the global [currentModelId], making a per-session model switch look
  /// like it never took effect.
  final Map<String, String> _sessionModel = {};
  final Map<String, String> _sessionProvider = {};

  /// Records the model/provider resolved for [sessionId]. A null/empty
  /// [modelId] clears the override (falls back to [currentModelId]).
  void setSessionModel(String sessionId, String? modelId, {String? providerId}) {
    if (modelId == null || modelId.isEmpty) {
      _sessionModel.remove(sessionId);
    } else {
      _sessionModel[sessionId] = modelId;
    }
    if (providerId != null && providerId.isNotEmpty) {
      _sessionProvider[sessionId] = providerId;
    }
  }

  /// The model/provider to stamp on [sessionId]'s assistant messages.
  String? modelForSession(String sessionId) =>
      _sessionModel[sessionId] ?? currentModelId;
  String? providerForSession(String sessionId) =>
      _sessionProvider[sessionId] ?? currentProviderId;

  /// Per-session project directory (an ACP project id *is* its `cwd`). The
  /// plugin records it so `session_info_update` (title) events are filed under
  /// the session's real project, not the launch [launchDirectory]. The mobile
  /// session list drops `session.updated` events whose projectID does not match
  /// the active project, so a session opened outside the launch directory would
  /// otherwise have its title updates ignored (or misrouted to the launch
  /// project).
  final Map<String, String> _sessionProject = {};

  /// Records the project directory [sessionId] belongs to. A null/empty
  /// [directory] clears the override (falls back to [launchDirectory]).
  void setSessionProject(String sessionId, String? directory) {
    if (directory == null || directory.isEmpty) {
      _sessionProject.remove(sessionId);
    } else {
      _sessionProject[sessionId] = directory;
    }
  }

  /// The project id/directory to stamp on [sessionId]'s session-level events.
  String projectForSession(String sessionId) =>
      _sessionProject[sessionId] ?? launchDirectory;

  /// sessionId -> current turn number, advanced by [beginTurn].
  final Map<String, int> _turnSeq = {};

  /// Per-session part ids whose envelope/part has already been emitted in the
  /// current turn. Scoped per session and pruned on [beginTurn] so it cannot
  /// grow without bound across a long-running session.
  final Map<String, Set<String>> _startedParts = {};

  /// Advance the turn counter for [sessionId]. Call before `session/prompt`
  /// so the next batch of streamed chunks groups under a fresh message id.
  void beginTurn(String sessionId) {
    _turnSeq[sessionId] = (_turnSeq[sessionId] ?? 0) + 1;
    // The new turn uses fresh (turn-numbered) part ids, so the prior turn's are
    // dead weight — drop them to bound memory in long sessions.
    _startedParts.remove(sessionId);
  }

  int _turn(String sessionId) => _turnSeq[sessionId] ?? 1;

  /// Maps a single notification to zero or more bridge events.
  List<BridgeSseEvent> map(AcpNotification notification) {
    if (notification.method != AcpMethods.sessionUpdate) {
      return mapExtension(notification);
    }
    final params = notification.params;
    final sessionId = params["sessionId"] as String?;
    final update = _asMap(params["update"]);
    if (sessionId == null || sessionId.isEmpty || update == null) {
      return const [];
    }

    switch (update["sessionUpdate"] as String?) {
      case "agent_message_chunk":
        return _textChunk(
          sessionId: sessionId,
          update: update,
          role: _ChunkRole.assistant,
          partSuffix: "text",
          partType: PluginMessagePartType.text,
        );
      case "agent_thought_chunk":
        return _textChunk(
          sessionId: sessionId,
          update: update,
          role: _ChunkRole.assistant,
          partSuffix: "reasoning",
          partType: PluginMessagePartType.reasoning,
        );
      case "user_message_chunk":
        return _textChunk(
          sessionId: sessionId,
          update: update,
          role: _ChunkRole.user,
          partSuffix: "text",
          partType: PluginMessagePartType.text,
        );
      case "tool_call":
        return _toolCall(sessionId: sessionId, update: update);
      case "tool_call_update":
        return _toolCallUpdate(sessionId: sessionId, update: update);
      case "plan":
        return [BridgeSseTodoUpdated(sessionID: sessionId)];
      case "available_commands_update":
        return const [BridgeSseProjectUpdated()];
      case "session_info_update":
        // The agent's auto-generated title for the thread. Surfaced as a
        // session update so the mobile session list / app bar live-update.
        final title = update["title"] as String?;
        if (title == null || title.isEmpty) return const [];
        return [
          BridgeSseSessionUpdated(info: _minimalSession(sessionId, title).toJson()),
        ];
    }

    // Dropped intentionally: current_mode_update (the mode is surfaced as the
    // session "variant", driven by the plugin, not a message event), and any
    // future standard variants the mobile UI has no renderer for.
    return const [];
  }

  /// Hook for non-`session/update` notifications (harness extensions such as
  /// Cursor's `cursor/update_todos`). Base implementation drops them.
  List<BridgeSseEvent> mapExtension(AcpNotification notification) => const [];

  List<BridgeSseEvent> _textChunk({
    required String sessionId,
    required Map<String, dynamic> update,
    required _ChunkRole role,
    required String partSuffix,
    required PluginMessagePartType partType,
  }) {
    final text = acpContentText(update["content"]);
    if (text == null || text.isEmpty) return const [];

    final messageId = "$sessionId-t${_turn(sessionId)}-${role.name}";
    final partId = "$messageId-$partSuffix";

    final events = <BridgeSseEvent>[];
    final started = _startedParts.putIfAbsent(sessionId, () => <String>{});
    if (started.add(partId)) {
      events.add(
        BridgeSseMessageUpdated(info: _messageFor(role, messageId, sessionId).toJson()),
      );
      events.add(
        BridgeSseMessagePartUpdated(
          part: _part(
            partId: partId,
            messageId: messageId,
            sessionId: sessionId,
            type: partType,
            text: "",
          ),
        ),
      );
    }
    events.add(
      BridgeSseMessagePartDelta(
        sessionID: sessionId,
        messageID: messageId,
        partID: partId,
        field: "text",
        delta: text,
      ),
    );
    return events;
  }

  List<BridgeSseEvent> _toolCall({
    required String sessionId,
    required Map<String, dynamic> update,
  }) {
    final toolCallId = update["toolCallId"] as String?;
    if (toolCallId == null || toolCallId.isEmpty) return const [];
    final messageId = "$sessionId-tool-$toolCallId";
    final partId = "$messageId-call";
    final title = update["title"] as String?;
    final status = acpToolStatus(update["status"]);
    final output = acpToolOutputText(update);
    return [
      BridgeSseMessageUpdated(
        info: shared.Message.assistant(
          id: messageId,
          sessionID: sessionId,
          agent: agentId,
          modelID: modelForSession(sessionId),
          providerID: providerForSession(sessionId),
          // ACP carries no per-message timestamps; the mobile model treats
          // a null time as "unknown".
          time: null,
        ).toJson(),
      ),
      BridgeSseMessagePartUpdated(
        part: _toolPart(
          partId: partId,
          messageId: messageId,
          sessionId: sessionId,
          // Same fail-soft name resolution as tool_call_update: `kind`, else
          // `title`, else "tool" — never an empty `kind`, never a throw on a
          // non-string field.
          tool: acpToolName(update),
          state: PluginToolState(
            status: status,
            title: title,
            output: output,
            error: status == PluginToolStatus.error ? output : null,
          ),
        ),
      ),
    ];
  }

  List<BridgeSseEvent> _toolCallUpdate({
    required String sessionId,
    required Map<String, dynamic> update,
  }) {
    final toolCallId = update["toolCallId"] as String?;
    if (toolCallId == null || toolCallId.isEmpty) return const [];
    final messageId = "$sessionId-tool-$toolCallId";
    final partId = "$messageId-call";
    final status = acpToolStatus(update["status"]);
    final output = acpToolOutputText(update);
    final events = <BridgeSseEvent>[
      BridgeSseMessagePartUpdated(
        part: _toolPart(
          partId: partId,
          messageId: messageId,
          sessionId: sessionId,
          tool: acpToolName(update),
          state: PluginToolState(
            status: status,
            title: update["title"] as String?,
            output: output,
            error: status == PluginToolStatus.error ? output : null,
          ),
        ),
      ),
    ];
    if (_isFileMutation(update)) {
      events.add(BridgeSseSessionDiff(sessionID: sessionId));
    }
    return events;
  }

  shared.Message _messageFor(_ChunkRole role, String messageId, String sessionId) {
    return switch (role) {
      _ChunkRole.user => shared.Message.user(
        id: messageId,
        sessionID: sessionId,
        agent: null,
        time: null,
      ),
      _ChunkRole.assistant => shared.Message.assistant(
        id: messageId,
        sessionID: sessionId,
        agent: agentId,
        modelID: modelForSession(sessionId),
        providerID: providerForSession(sessionId),
        time: null,
      ),
    };
  }

  /// A minimal [shared.Session] for a `session_info_update`; the bridge
  /// enrichment + mobile merge it against existing state, so only the id and
  /// title matter here.
  shared.Session _minimalSession(String id, String? title) {
    final project = projectForSession(id);
    return shared.Session(
      id: id,
      projectID: project,
      directory: project,
      parentID: null,
      title: title,
      time: null,
      summary: null,
      pullRequest: null,
      promptDefaults: null,
    );
  }

  PluginMessagePart _part({
    required String partId,
    required String messageId,
    required String sessionId,
    required PluginMessagePartType type,
    required String text,
  }) {
    return PluginMessagePart(
      id: partId,
      sessionID: sessionId,
      messageID: messageId,
      type: type,
      text: text,
      tool: null,
      state: null,
      prompt: null,
      description: null,
      agent: null,
      agentName: null,
      attempt: null,
      retryError: null,
    );
  }

  PluginMessagePart _toolPart({
    required String partId,
    required String messageId,
    required String sessionId,
    required String tool,
    required PluginToolState state,
  }) {
    return PluginMessagePart(
      id: partId,
      sessionID: sessionId,
      messageID: messageId,
      type: PluginMessagePartType.tool,
      text: null,
      tool: tool,
      state: state,
      prompt: null,
      description: null,
      agent: null,
      agentName: null,
      attempt: null,
      retryError: null,
    );
  }

  bool _isFileMutation(Map<String, dynamic> update) {
    final kind = update["kind"] as String?;
    return kind == "edit" || kind == "delete" || kind == "move";
  }

  Map<String, dynamic>? _asMap(Object? value) {
    if (value is Map) return value.cast<String, dynamic>();
    return null;
  }
}

enum _ChunkRole { user, assistant }
