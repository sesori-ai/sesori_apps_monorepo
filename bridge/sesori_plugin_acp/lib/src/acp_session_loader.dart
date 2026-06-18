import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

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
        final t = _contentText(update["content"]);
        if (t != null) _assistant().text.write(t);
      case "agent_thought_chunk":
        final t = _contentText(update["content"]);
        if (t != null) _assistant().reasoning.write(t);
      case "user_message_chunk":
        final t = _contentText(update["content"]);
        if (t != null) _user().text.write(t);
      case "tool_call":
        final id = update["toolCallId"] as String?;
        if (id == null) return;
        _assistant().tools[id] = _ToolDraft(
          tool: (update["kind"] ?? update["title"] ?? "tool") as String,
          title: update["title"] as String?,
          status: _status(update["status"]),
          output: _toolOutput(update),
        );
      case "tool_call_update":
        final id = update["toolCallId"] as String?;
        if (id == null) return;
        final draft = _findTool(id);
        if (draft == null) return;
        draft.status = _status(update["status"]);
        final out = _toolOutput(update);
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

  _Draft _assistant() => _ensureRole("assistant");
  _Draft _user() => _ensureRole("user");

  _Draft _ensureRole(String role) {
    if (_drafts.isNotEmpty && _drafts.last.role == role) return _drafts.last;
    final draft = _Draft(role: role, id: "$sessionId-h${_seq++}-$role");
    _drafts.add(draft);
    return draft;
  }

  _ToolDraft? _findTool(String toolId) {
    for (final draft in _drafts.reversed) {
      final tool = draft.tools[toolId];
      if (tool != null) return tool;
    }
    return null;
  }

  PluginToolStatus _status(Object? raw) {
    return switch (raw) {
      "pending" => PluginToolStatus.pending,
      "in_progress" => PluginToolStatus.running,
      "completed" => PluginToolStatus.completed,
      "failed" => PluginToolStatus.error,
      _ => PluginToolStatus.pending,
    };
  }

  /// Tool output for replayed `tool_call`/`tool_call_update`: ACP `content`
  /// block first, else the harness `rawOutput` (cursor's exec stdout/stderr),
  /// truncated to [maxToolOutputLength].
  String? _toolOutput(Map<String, dynamic> update) {
    final text = _contentText(update["content"]) ?? _rawOutputText(update["rawOutput"]);
    if (text == null || text.isEmpty) return null;
    return text.length > maxToolOutputLength
        ? "${text.substring(0, maxToolOutputLength)}…"
        : text;
  }

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

  String? _contentText(Object? content) {
    if (content is String) return content.isEmpty ? null : content;
    if (content is Map) {
      final text = content["text"];
      return text is String && text.isNotEmpty ? text : null;
    }
    if (content is List) {
      final buffer = StringBuffer();
      for (final entry in content) {
        if (entry is Map) {
          final text = entry["text"];
          if (text is String) buffer.write(text);
        }
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

class _Draft {
  _Draft({required this.role, required this.id});

  final String role;
  final String id;
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
  final String? title;
  // Reassigned as later tool_call_update notifications arrive during replay.
  PluginToolStatus status;
  String? output;
}
