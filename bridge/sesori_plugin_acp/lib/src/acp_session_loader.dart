import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show PluginToolStatus;

import "acp_event_mapper.dart" show AcpHaltNotice;
import "repositories/models/acp_notification_record.dart";

/// Accumulates the `session/update` notifications replayed by `session/load`
/// into ordered typed backend records for the Layer-2 message repository.
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
    required this.haltClassifier,
  });

  final String sessionId;
  final String agentId;

  /// Classifies a fully-accumulated assistant message as a backend halt notice
  /// (see [AcpEventMapper.classifyHaltNotice]) so a reloaded session renders the
  /// notice as an error message exactly as it appeared live. Null on backends
  /// with no halt notices.
  final AcpHaltNotice? Function({required String text})? haltClassifier;

  /// Model/provider stamped on replayed assistant messages. Mutable so the
  /// plugin can set the loaded session's real model after `session/load`
  /// returns its catalog (the collector is created before the load runs).
  String? modelId;
  String? providerId;

  final List<_Draft> _drafts = [];
  int _seq = 0;

  void consume(AcpNotificationRecord notification) {
    if (notification is! AcpSessionNotificationRecord || notification.sessionId != sessionId) {
      return;
    }
    switch (notification) {
      case AcpMessageChunkRecord(
        :final role,
        :final messageId,
        :final text,
      ):
        if (text == null) return;
        switch (role) {
          case AcpMessageChunkRole.assistant:
            _assistant(messageId: messageId).text.write(text);
          case AcpMessageChunkRole.thought:
            _assistant(messageId: messageId).reasoning.write(text);
          case AcpMessageChunkRole.user:
            _user(messageId: messageId).text.write(text);
        }
      case AcpToolUpdateRecord(isInitial: true):
        final id = notification.toolCallId;
        if (id == null) return;
        _assistantForTool().tools[id] = _ToolDraft(
          tool: notification.toolName,
          title: notification.title,
          status: notification.status,
          output: notification.output,
        );
      case AcpToolUpdateRecord():
        final id = notification.toolCallId;
        if (id == null) return;
        final draft = _findTool(id);
        if (draft == null) {
          // No prior `tool_call` was replayed for this id (loaded history can
          // carry only the update). Seed a tool draft from the update payload so
          // the card still renders, mirroring the live mapper which emits a tool
          // part unconditionally.
          _assistantForTool().tools[id] = _ToolDraft(
            tool: notification.toolName,
            title: notification.title,
            status: notification.status,
            output: notification.output,
          );
          return;
        }
        // A `tool_call_update` is partial: only advance a field when the update
        // carries it, else a later output-only update would reset a
        // completed/failed replayed tool card back to pending (status) or drop a
        // separately-sent display title. Mirrors the live mapper's merge so
        // replayed history matches live rendering.
        if (notification.hasStatus) draft.status = notification.status;
        if (notification.hasTitle) draft.title = notification.title;
        if (notification.output != null) draft.output = notification.output;
      case AcpPlanChangedRecord() ||
          AcpAvailableCommandsChangedRecord() ||
          AcpSessionInfoChangedRecord() ||
          AcpIgnoredSessionNotificationRecord():
        return;
      case AcpExtensionNotificationRecord():
        return;
    }
  }

  List<AcpReplayMessage> build() {
    return [
      for (final draft in _drafts) _buildMessage(draft),
    ];
  }

  AcpReplayMessage _buildMessage(_Draft draft) {
    // A recognized halt notice (e.g. Cursor's account/plan gate, streamed as a
    // lone assistant message) is surfaced as an error message so a reloaded
    // session matches the live rendering. Only a pure-text terminal notice
    // qualifies — no reasoning, no tools — matching the shape the backend emits.
    if (draft.role == "assistant" && draft.reasoning.isEmpty && draft.tools.isEmpty && draft.text.isNotEmpty) {
      final halt = haltClassifier?.call(text: draft.text.toString());
      if (halt != null) {
        return AcpReplayMessage(
          id: draft.id,
          role: AcpReplayRole.assistant,
          text: draft.text.toString(),
          reasoning: "",
          tools: const [],
          errorName: halt.errorName,
          errorMessage: halt.message,
        );
      }
    }
    return AcpReplayMessage(
      id: draft.id,
      role: draft.role == "user" ? AcpReplayRole.user : AcpReplayRole.assistant,
      text: draft.text.toString(),
      reasoning: draft.reasoning.toString(),
      tools: [
        for (final entry in draft.tools.entries)
          AcpReplayTool(
            id: entry.key,
            name: entry.value.tool,
            title: entry.value.title,
            status: entry.value.status,
            output: entry.value.output,
          ),
      ],
      errorName: null,
      errorMessage: null,
    );
  }

  _Draft _assistant({String? messageId}) => _ensureRole("assistant", messageId: messageId);
  _Draft _user({String? messageId}) => _ensureRole("user", messageId: messageId);

  // Tool calls carry no messageId (they are not ContentChunks) and attach to
  // the current assistant message even when its content chunks are stamped.
  _Draft _assistantForTool() {
    if (_drafts.isNotEmpty && _drafts.last.role == "assistant") {
      final last = _drafts.last;
      if (last.acpMessageId != null || (last.text.isEmpty && last.reasoning.isEmpty)) {
        return last;
      }
    }
    return _newDraft("assistant", messageId: null);
  }

  /// The draft the next chunk belongs to. ACP v1: chunks of one message share
  /// a `messageId`, and a change starts a new message — so the last draft is
  /// reused only when both the role AND the message id match. An id-less
  /// content chunk continues only an id-less draft; tool attachments use
  /// [_assistantForTool] because ACP does not stamp them. Comparison is against
  /// the last draft only, matching the spec's sequential semantics.
  _Draft _ensureRole(String role, {String? messageId}) {
    if (_drafts.isNotEmpty && _drafts.last.role == role) {
      final last = _drafts.last;
      if (last.acpMessageId == messageId && !(messageId == null && last.tools.isNotEmpty)) {
        return last;
      }
    }
    return _newDraft(role, messageId: messageId);
  }

  _Draft _newDraft(String role, {required String? messageId}) {
    final draft = _Draft(
      role: role,
      id: messageId != null && messageId.isNotEmpty ? "$sessionId-m$messageId-$role" : "$sessionId-h${_seq++}-$role",
      acpMessageId: messageId,
    );
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
}

class _Draft {
  _Draft({required this.role, required this.id, required this.acpMessageId});

  final String role;
  final String id;

  /// The ACP `messageId` this draft groups, when the agent stamped one.
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

enum AcpReplayRole { user, assistant }

class AcpReplayMessage {
  const AcpReplayMessage({
    required this.id,
    required this.role,
    required this.text,
    required this.reasoning,
    required this.tools,
    required this.errorName,
    required this.errorMessage,
  });

  final String id;
  final AcpReplayRole role;
  final String text;
  final String reasoning;
  final List<AcpReplayTool> tools;
  final String? errorName;
  final String? errorMessage;
}

class AcpReplayTool {
  const AcpReplayTool({
    required this.id,
    required this.name,
    required this.title,
    required this.status,
    required this.output,
  });

  final String id;
  final String name;
  final String? title;
  final PluginToolStatus status;
  final String? output;
}
