import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "acp_content.dart";

/// Accumulates the `session/update` notifications replayed by `session/load`
/// into ordered [PluginMessageWithParts] for `getSessionMessages`.
///
/// ACP replays a thread as a stream of chunk notifications in conversational
/// order; consecutive same-role chunks belong to one message, and a role
/// switch starts a new message.
class AcpReplayCollector {
  AcpReplayCollector({
    required this.sessionId,
    required this.agentId,
    this.modelId,
    this.providerId,
  });

  final String sessionId;
  final String agentId;

  /// Model/provider stamped on replayed assistant messages. Mutable so the
  /// plugin can set the loaded session's real model after `session/load`
  /// returns its catalog (the collector is created before the load runs).
  String? modelId;
  String? providerId;

  final List<_Draft> _drafts = [];
  int _seq = 0;

  void consume(Map<String, dynamic> params) {
    final update = _asMap(params["update"]);
    if (update == null) return;
    switch (update["sessionUpdate"] as String?) {
      case "agent_message_chunk":
        final t = acpContentText(update["content"]);
        if (t != null) _assistant(messageId: _chunkMessageId(update)).text.write(t);
      case "agent_thought_chunk":
        final t = acpContentText(update["content"]);
        if (t != null) _assistant(messageId: _chunkMessageId(update)).reasoning.write(t);
      case "user_message_chunk":
        final t = acpContentText(update["content"]);
        if (t != null) _user(messageId: _chunkMessageId(update)).text.write(t);
      case "tool_call":
        final id = update["toolCallId"] as String?;
        if (id == null) return;
        _assistant().tools[id] = _ToolDraft(
          tool: acpToolName(update),
          title: _toolTitle(update),
          status: acpToolStatus(update["status"]),
          output: acpToolOutputText(update),
        );
      case "tool_call_update":
        final id = update["toolCallId"] as String?;
        if (id == null) return;
        final draft = _findTool(id);
        if (draft == null) {
          // No prior `tool_call` was replayed for this id (loaded history can
          // carry only the update). Seed a tool draft from the update payload so
          // the card still renders, mirroring the live mapper which emits a tool
          // part unconditionally.
          _assistant().tools[id] = _ToolDraft(
            tool: acpToolName(update),
            title: _toolTitle(update),
            status: acpToolStatus(update["status"]),
            output: acpToolOutputText(update),
          );
          return;
        }
        // A `tool_call_update` is partial: only advance a field when the update
        // carries it, else a later output-only update would reset a
        // completed/failed replayed tool card back to pending (status) or drop a
        // separately-sent display title. Mirrors the live mapper's merge so
        // replayed history matches live rendering.
        if (update.containsKey("status")) draft.status = acpToolStatus(update["status"]);
        if (update.containsKey("title")) draft.title = _toolTitle(update);
        final out = acpToolOutputText(update);
        if (out != null) draft.output = out;
    }
  }

  List<PluginMessageWithParts> build() {
    return [
      for (final draft in _drafts) _buildMessage(draft),
    ];
  }

  PluginMessageWithParts _buildMessage(_Draft draft) {
    final parts = <PluginMessagePart>[];
    if (draft.reasoning.isNotEmpty) {
      parts.add(_textPart(draft, "reasoning", PluginMessagePartType.reasoning, draft.reasoning.toString()));
    }
    if (draft.text.isNotEmpty) {
      parts.add(_textPart(draft, "text", PluginMessagePartType.text, draft.text.toString()));
    }
    draft.tools.forEach((toolId, tool) {
      parts.add(
        PluginMessagePart(
          id: "${draft.id}-tool-$toolId",
          sessionID: sessionId,
          messageID: draft.id,
          type: PluginMessagePartType.tool,
          text: null,
          tool: tool.tool,
          state: PluginToolState(
            status: tool.status,
            title: tool.title,
            output: tool.output,
            error: tool.status == PluginToolStatus.error ? tool.output : null,
          ),
          prompt: null,
          description: null,
          agent: null,
          agentName: null,
          attempt: null,
          retryError: null,
        ),
      );
    });
    return PluginMessageWithParts(info: _message(draft), parts: parts);
  }

  PluginMessage _message(_Draft draft) {
    if (draft.role == "user") {
      return PluginMessage.user(
        id: draft.id,
        sessionID: sessionId,
        agent: null,
        time: null,
      );
    }
    return PluginMessage.assistant(
      id: draft.id,
      sessionID: sessionId,
      agent: agentId,
      modelID: modelId,
      providerID: providerId,
      time: null,
    );
  }

  PluginMessagePart _textPart(
    _Draft draft,
    String suffix,
    PluginMessagePartType type,
    String text,
  ) {
    return PluginMessagePart(
      id: "${draft.id}-$suffix",
      sessionID: sessionId,
      messageID: draft.id,
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

  // Tool calls carry no messageId (they are not ContentChunks) and attach to
  // the current assistant message, so the tool paths call these without one.
  _Draft _assistant({String? messageId}) => _ensureRole("assistant", messageId: messageId);
  _Draft _user({String? messageId}) => _ensureRole("user", messageId: messageId);

  /// The draft the next chunk belongs to. ACP v1: chunks of one message share
  /// a `messageId`, and a change starts a new message — so the last draft is
  /// reused only when both the role AND the message id match (a chunk without
  /// an id, tool attachment included, always continues the current same-role
  /// message). Comparison is against the last draft only, matching the spec's
  /// sequential "a change indicates a new message" semantics.
  _Draft _ensureRole(String role, {String? messageId}) {
    if (_drafts.isNotEmpty && _drafts.last.role == role) {
      final last = _drafts.last;
      if (messageId == null || last.acpMessageId == null || last.acpMessageId == messageId) {
        // Adopt the id when the running draft was started by id-less chunks:
        // agents may stamp ids only on some chunk kinds of one message.
        last.acpMessageId ??= messageId;
        return last;
      }
    }
    final draft = _Draft(
      role: role,
      id: messageId != null && messageId.isNotEmpty
          ? "$sessionId-m$messageId-$role"
          : "$sessionId-h${_seq++}-$role",
      acpMessageId: messageId,
    );
    _drafts.add(draft);
    return draft;
  }

  /// The chunk's ACP `messageId`, when present and well-formed.
  static String? _chunkMessageId(Map<String, dynamic> update) {
    final id = update["messageId"];
    return id is String && id.isNotEmpty ? id : null;
  }

  _ToolDraft? _findTool(String toolId) {
    for (final draft in _drafts.reversed) {
      final tool = draft.tools[toolId];
      if (tool != null) return tool;
    }
    return null;
  }

  Map<String, dynamic>? _asMap(Object? value) {
    if (value is Map) return value.cast<String, dynamic>();
    return null;
  }

  /// Fail-soft tool title: a non-string value (schema drift / malformed agent
  /// data) renders as null rather than throwing mid-replay, which would fail
  /// the whole `/session/messages` history load.
  static String? _toolTitle(Map<String, dynamic> update) =>
      update["title"] is String ? update["title"] as String? : null;
}

class _Draft {
  _Draft({required this.role, required this.id, required this.acpMessageId});

  final String role;
  final String id;

  /// The ACP `messageId` this draft groups, when the agent stamped one.
  /// Adopted late when the first stamped chunk arrives mid-message.
  String? acpMessageId;
  final StringBuffer text = StringBuffer();
  final StringBuffer reasoning = StringBuffer();
  final Map<String, _ToolDraft> tools = {};
}

class _ToolDraft {
  _ToolDraft({
    required this.tool,
    required this.title,
    required this.status,
    required this.output,
  });

  final String tool;
  // Reassigned as later tool_call_update notifications arrive during replay.
  String? title;
  PluginToolStatus status;
  String? output;
}
