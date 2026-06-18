import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart" as shared;

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
  AcpEventMapper({required this.projectCwd, required this.agentId});

  /// The bridge launch CWD — the single synthesized project id.
  final String projectCwd;

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

  /// sessionId -> current turn number, advanced by [beginTurn].
  final Map<String, int> _turnSeq = {};

  /// Part ids whose envelope/part has already been emitted this run.
  final Set<String> _startedParts = {};

  /// Advance the turn counter for [sessionId]. Call before `session/prompt`
  /// so the next batch of streamed chunks groups under a fresh message id.
  void beginTurn(String sessionId) {
    _turnSeq[sessionId] = (_turnSeq[sessionId] ?? 0) + 1;
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
    final text = _contentText(update["content"]);
    if (text == null || text.isEmpty) return const [];

    final messageId = "$sessionId-t${_turn(sessionId)}-${role.name}";
    final partId = "$messageId-$partSuffix";

    final events = <BridgeSseEvent>[];
    if (_startedParts.add(partId)) {
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
    _startedParts.add(partId);
    final title = update["title"] as String?;
    final kind = update["kind"] as String?;
    final status = _toolStatus(update["status"]);
    final output = toolOutputText(update);
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
          tool: kind ?? title ?? "tool",
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
    final status = _toolStatus(update["status"]);
    final output = toolOutputText(update);
    final events = <BridgeSseEvent>[
      BridgeSseMessagePartUpdated(
        part: _toolPart(
          partId: partId,
          messageId: messageId,
          sessionId: sessionId,
          tool: (update["kind"] ?? update["title"] ?? "tool") as String,
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
    return shared.Session(
      id: id,
      projectID: projectCwd,
      directory: projectCwd,
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

  /// Normalizes an ACP tool-call status onto the [PluginToolStatus] the mobile
  /// tool renderer consumes. Tuned during end-to-end verification.
  PluginToolStatus _toolStatus(Object? raw) {
    return switch (raw) {
      "pending" => PluginToolStatus.pending,
      "in_progress" => PluginToolStatus.running,
      "completed" => PluginToolStatus.completed,
      "failed" => PluginToolStatus.error,
      _ => PluginToolStatus.pending,
    };
  }

  bool _isFileMutation(Map<String, dynamic> update) {
    final kind = update["kind"] as String?;
    return kind == "edit" || kind == "delete" || kind == "move";
  }

  /// Tool output for a `tool_call`/`tool_call_update`: prefers an ACP
  /// `content` block, else falls back to the harness `rawOutput` (cursor
  /// reports an executed command's stdout/stderr there, not in `content`).
  /// Truncated to [maxToolOutputLength] so the mobile tool renderer is not
  /// flooded by large command output.
  String? toolOutputText(Map<String, dynamic> update) {
    final text = _contentText(update["content"]) ?? _rawOutputText(update["rawOutput"]);
    if (text == null || text.isEmpty) return null;
    return text.length > maxToolOutputLength
        ? "${text.substring(0, maxToolOutputLength)}…"
        : text;
  }

  /// Flattens a `rawOutput` block into displayable text. Exec-style tools report
  /// `{exitCode, stdout, stderr}`; read/other tools report `{content}` (string
  /// or ContentBlock(s)); some report a bare string.
  String? _rawOutputText(Object? raw) {
    if (raw is String) return raw.isEmpty ? null : raw;
    if (raw is! Map) return null;
    final map = raw.cast<String, dynamic>();
    final out = (map["stdout"] as String?)?.trimRight() ?? "";
    final err = (map["stderr"] as String?)?.trimRight() ?? "";
    if (out.isNotEmpty || err.isNotEmpty) {
      final buffer = StringBuffer(out);
      if (err.isNotEmpty) {
        if (buffer.isNotEmpty) buffer.write("\n");
        buffer.write(err);
      }
      return buffer.toString();
    }
    final content = _contentText(map["content"])?.trimRight();
    return (content == null || content.isEmpty) ? null : content;
  }

  /// Extracts text from an ACP `ContentBlock` (`{type:text,text}`) or a list
  /// of them.
  String? _contentText(Object? content) {
    if (content is String) return content.isEmpty ? null : content;
    if (content is Map) {
      final text = content["text"];
      return text is String && text.isNotEmpty ? text : null;
    }
    if (content is List) {
      final buffer = StringBuffer();
      for (final entry in content) {
        final map = _asMap(entry);
        final text = map?["text"];
        if (text is String) buffer.write(text);
      }
      final result = buffer.toString();
      return result.isEmpty ? null : result;
    }
    return null;
  }

  Map<String, dynamic>? _asMap(Object? value) {
    if (value is Map) return value.cast<String, dynamic>();
    return null;
  }
}

enum _ChunkRole { user, assistant }
