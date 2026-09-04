import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart" as shared;

import "api/models/claude_stream_message.dart";
import "models/claude_task_notification.dart";
import "models/claude_tool_use_result.dart";
import "repositories/mappers/claude_api_error_mapper.dart";
import "repositories/mappers/claude_content_mapper.dart";
import "repositories/trackers/claude_tool_tracker.dart";

/// Dispatches Claude stream-json frames as bridge-neutral live events.
final class ClaudeEventDispatcher({
  required final ClaudeContentMapper _content,
  required final ClaudeToolTracker _tools,
}) {
  final Map<String, String> _messageIds = {};
  final Map<String, String> _announcedMessageIds = {};
  final Map<String, String> _models = {};
  final Map<String, Set<int>> _streamedBlocks = {};
  final Map<String, Map<int, PluginMessagePart>> _completedStreamedParts = {};
  final Map<String, Set<String>> _streamedMessageIds = {};
  final Set<String> _mappedApiErrorSessions = {};

  /// Content blocks already carried by `assistant` frames, per message id.
  ///
  /// Claude Code emits one `assistant` frame per content block under the same
  /// `message.id`, so every frame's own content restarts at offset 0. Blocks
  /// are numbered across the whole message instead, matching the stream's
  /// block index and the transcript history; otherwise a block streamed at
  /// index >= 1 is finalized under a second part id and renders twice.
  final Map<String, int> _assistantBlockCounts = {};

  /// The root directory each session runs in, recorded at [beginTurn] so a
  /// child session can be constructed without asking the plugin.
  final Map<String, String> _directories = {};

  /// Child sessions announced with `session.created`, and the subset still
  /// running, per root. Presentation state over the tracker's task map.
  final Map<String, Set<String>> _announcedChildren = {};
  final Map<String, Set<String>> _busyChildren = {};

  /// Child session → root session. Nested sub-agents are flattened under the
  /// root, so this is one level deep by construction.
  final Map<String, String> _roots = {};

  String _rootOf(String sessionId) => _roots[sessionId] ?? sessionId;

  void beginTurn({required String sessionId, required String directory}) {
    _directories[sessionId] = directory;
    _resetTurn(sessionId: sessionId);
  }

  /// Clears completed-turn stream state.
  void completeTurn({required String sessionId}) => _resetTurn(sessionId: sessionId);

  void _resetTurn({required String sessionId}) {
    _messageIds.remove(sessionId);
    _announcedMessageIds.remove(sessionId);
    _mappedApiErrorSessions.remove(sessionId);
    _clearStreamedMessages(sessionId: sessionId);
    _tools.beginTurn(sessionId: sessionId);
  }

  void forgetSession({required String sessionId}) {
    for (final childId in _announcedChildren.remove(sessionId) ?? const <String>{}) {
      _forgetRendered(sessionId: childId);
      _roots.remove(childId);
    }
    _forgetRendered(sessionId: sessionId);
    _directories.remove(sessionId);
    _busyChildren.remove(sessionId);
    // A deleted child must also leave its root's membership sets, or it keeps
    // reporting a status and blocks a later re-announcement.
    if (_roots.remove(sessionId) case final root?) {
      _announcedChildren[root]?.remove(sessionId);
      _busyChildren[root]?.remove(sessionId);
    }
  }

  void _forgetRendered({required String sessionId}) {
    _messageIds.remove(sessionId);
    _announcedMessageIds.remove(sessionId);
    _mappedApiErrorSessions.remove(sessionId);
    _models.remove(sessionId);
    _clearStreamedMessages(sessionId: sessionId);
    _tools.forgetSession(sessionId: sessionId);
  }

  /// Cancels every running sub-agent task of root [sessionId] and its children
  /// — their process is gone — and returns the subtask part updates and child
  /// idle statuses that make that visible.
  List<BridgeSseEvent> cancelTasks({required String sessionId}) => [
    for (final owner in {sessionId, ...?_announcedChildren[sessionId]})
      for (final task in _tools.cancelAll(sessionId: owner)) ..._partEvents(tool: task),
  ];

  /// Statuses of the child sessions this dispatcher announced, for every root.
  Map<String, PluginSessionStatus> childSessionStatuses() => {
    for (final entry in _announcedChildren.entries)
      for (final childId in entry.value)
        childId: _busyChildren[entry.key]?.contains(childId) ?? false
            ? const PluginSessionStatus.busy()
            : const PluginSessionStatus.idle(),
  };

  /// The child sessions of [sessionId] still running.
  List<String> busyChildSessionIds({required String sessionId}) => [...?_busyChildren[sessionId]];

  /// Tool-use ids of the tasks still running inside the session's resident
  /// process; a replayed task outside this set is dead.
  Set<String> residentTaskToolUseIds({required String sessionId}) => _tools.runningTaskToolUseIds(sessionId: sessionId);

  void _clearStreamedMessages({required String sessionId}) {
    final messageIds = _streamedMessageIds.remove(sessionId);
    if (messageIds == null) return;
    for (final messageId in messageIds) {
      _streamedBlocks.remove(messageId);
      _completedStreamedParts.remove(messageId);
      _assistantBlockCounts.remove(messageId);
    }
  }

  PluginSessionStatus? retryStatus({
    required ClaudeApiRetryMessage message,
    required DateTime now,
  }) {
    final attempt = message.attempt;
    final delay = message.retryDelayMs;
    if (attempt == null || delay == null) return null;
    return PluginSessionStatus.retry(
      attempt: attempt,
      message: _retryMessage(message),
      next: now.millisecondsSinceEpoch + delay,
    );
  }

  List<BridgeSseEvent> map({required ClaudeStreamMessage message, DateTime? now}) {
    if (message.sessionId case final sessionId? when sessionId.isNotEmpty) {
      // A forwarded sub-agent frame renders in that sub-agent's child session,
      // resolved from the launching task; before the task knows its sub-agent
      // id there is no session to render into, so the frame is dropped.
      if (message
          case ClaudeAssistantMessage(:final String parentToolUseId) ||
              ClaudeUserMessage(:final String parentToolUseId) ||
              ClaudeStreamEventMessage(:final String parentToolUseId)) {
        final childId = _tools.childSessionIdForToolUse(toolUseId: parentToolUseId);
        if (childId == null) return const [];
        _roots[childId] = _rootOf(sessionId);
        return switch (message) {
          ClaudeStreamEventMessage() => _mapStream(sessionId: childId, message: message),
          ClaudeAssistantMessage() => _mapAssistant(sessionId: childId, message: message),
          ClaudeUserMessage() => _mapUser(sessionId: childId, message: message, promptId: null),
          _ => const [],
        };
      }
      return switch (message) {
        ClaudeStreamEventMessage() => _mapStream(sessionId: sessionId, message: message),
        ClaudeAssistantMessage() => _mapAssistant(sessionId: sessionId, message: message),
        ClaudeUserMessage() => _mapUser(sessionId: sessionId, message: message, promptId: null),
        ClaudeApiRetryMessage() => _mapRetry(sessionId: sessionId, message: message, now: now ?? DateTime.now()),
        ClaudeResultMessage() => _mapResult(sessionId: sessionId, message: message),
        ClaudeTaskStartedMessage() => _mapTaskStarted(message: message),
        ClaudeTaskNotificationMessage() => _mapTaskNotification(message: message),
        ClaudeInitMessage() ||
        ClaudeStatusMessage() ||
        // ponytail: parsed but not surfaced — no client UI consumes thinking
        // token estimates, task/tool progress, or hook output yet.
        ClaudeThinkingTokensMessage() ||
        ClaudeTaskProgressMessage() ||
        ClaudeToolProgressMessage() ||
        ClaudeHookStartedMessage() ||
        ClaudeHookOutputMessage() ||
        ClaudeControlRequestMessage() ||
        ClaudeControlResponseMessage() ||
        ClaudeRateLimitMessage() ||
        ClaudeUnknownMessage() => const [],
      };
    }
    return const [];
  }

  /// Maps one bridge-dispatched stdin replay with its authoritative prompt id.
  List<BridgeSseEvent> mapPromptReplay({
    required ClaudeUserMessage message,
    required String promptId,
  }) {
    final sessionId = message.sessionId;
    if (sessionId == null || sessionId.isEmpty || message.parentToolUseId != null) return const [];
    return _mapUser(sessionId: sessionId, message: message, promptId: promptId);
  }

  List<BridgeSseEvent> _mapStream({
    required String sessionId,
    required ClaudeStreamEventMessage message,
  }) => switch (message.eventType) {
    ClaudeStreamEventType.messageStart => _messageStart(sessionId: sessionId, message: message),
    ClaudeStreamEventType.contentBlockStart => _contentStart(sessionId: sessionId, message: message),
    ClaudeStreamEventType.contentBlockDelta => _contentDelta(sessionId: sessionId, message: message),
    ClaudeStreamEventType.contentBlockStop => _contentStop(sessionId: sessionId, message: message),
    ClaudeStreamEventType.other => const [],
  };

  List<BridgeSseEvent> _messageStart({
    required String sessionId,
    required ClaudeStreamEventMessage message,
  }) {
    final rawMessage = _mapOrNull(message.event["message"]);
    final messageId = _nonEmptyString(rawMessage?["id"]);
    if (messageId == null) return const [];
    final model = _realModel(model: _nonEmptyString(rawMessage?["model"]));
    _messageIds[sessionId] = messageId;
    _streamedMessageIds.putIfAbsent(sessionId, () => <String>{}).add(messageId);
    if (model != null) _models[sessionId] = model;
    return const [];
  }

  List<BridgeSseEvent> _contentStart({
    required String sessionId,
    required ClaudeStreamEventMessage message,
  }) {
    final messageId = _messageIds[sessionId];
    final index = message.blockIndex;
    if (messageId == null || index == null) return const [];
    final blocks = _content.map(content: message.contentBlock);
    if (blocks.length != 1) return const [];
    final block = blocks.single;
    _streamedBlocks.putIfAbsent(messageId, () => <int>{}).add(index);
    final part = switch (block) {
      ClaudeMappedTextContentBlock() => _textPart(
        sessionId: sessionId,
        messageId: messageId,
        index: index,
        type: PluginMessagePartType.text,
        text: "",
      ),
      ClaudeMappedThinkingContentBlock() => _textPart(
        sessionId: sessionId,
        messageId: messageId,
        index: index,
        type: PluginMessagePartType.reasoning,
        text: "",
      ),
      ClaudeMappedToolUseContentBlock(:final id, :final name, :final input) =>
        _tools
            .start(
              sessionId: sessionId,
              messageId: messageId,
              blockIndex: index,
              toolId: id,
              name: name,
              input: input,
            )
            .toPart(),
      ClaudeMappedToolResultContentBlock() ||
      ClaudeMappedTaskNotificationContentBlock() ||
      ClaudeMappedImageContentBlock() ||
      ClaudeMappedUnsupportedContentBlock() ||
      ClaudeMappedUnknownContentBlock() => null,
    };
    return part == null
        ? const []
        : [
            ..._announceAssistant(sessionId: sessionId, messageId: messageId),
            BridgeSseMessagePartUpdated(part: part),
          ];
  }

  List<BridgeSseEvent> _contentDelta({
    required String sessionId,
    required ClaudeStreamEventMessage message,
  }) {
    final messageId = _messageIds[sessionId];
    final index = message.blockIndex;
    if (messageId == null || index == null) return const [];
    switch (message.deltaType) {
      case ClaudeStreamDeltaType.text:
      case ClaudeStreamDeltaType.thinking:
        final delta = _nonEmptyString(
          message.delta[message.deltaType == ClaudeStreamDeltaType.text ? "text" : "thinking"],
        );
        if (delta == null) return const [];
        return [
          BridgeSseMessagePartDelta(
            sessionID: sessionId,
            messageID: messageId,
            partID: "$messageId-block-$index",
            field: "text",
            delta: delta,
          ),
        ];
      case ClaudeStreamDeltaType.inputJson:
        final partialJson = message.delta["partial_json"];
        if (partialJson is! String) return const [];
        return _partEvents(
          tool: _tools.appendInput(
            sessionId: sessionId,
            messageId: messageId,
            blockIndex: index,
            partialJson: partialJson,
          ),
        );
      case ClaudeStreamDeltaType.other:
        return const [];
    }
  }

  List<BridgeSseEvent> _contentStop({
    required String sessionId,
    required ClaudeStreamEventMessage message,
  }) {
    final messageId = _messageIds[sessionId];
    final index = message.blockIndex;
    if (messageId == null || index == null) return const [];
    _streamedBlocks[messageId]?.remove(index);
    final tool = _tools.stopInput(sessionId: sessionId, messageId: messageId, blockIndex: index);
    final completed = _completedStreamedParts[messageId]?.remove(index);
    return [
      ..._partEvents(tool: tool),
      if (tool == null && completed != null) BridgeSseMessagePartUpdated(part: completed),
    ];
  }

  List<BridgeSseEvent> _mapAssistant({
    required String sessionId,
    required ClaudeAssistantMessage message,
  }) {
    final messageId = _nonEmptyString(message.messageId);
    if (messageId == null) return const [];
    _messageIds[sessionId] = messageId;
    _streamedMessageIds.putIfAbsent(sessionId, () => <String>{}).add(messageId);
    if (_realModel(model: message.model) case final model?) _models[sessionId] = model;
    final mapped = _content.map(content: message.message["content"]);
    if (message.error != ClaudeAssistantError.none) {
      _mappedApiErrorSessions.add(sessionId);
      final error = mapClaudeApiError(blocks: mapped, status: message.apiErrorStatus);
      return [
        BridgeSseMessageUpdated(
          info: PluginMessage.error(
            id: messageId,
            sessionID: sessionId,
            agent: "claude",
            modelID: _models[sessionId],
            providerID: "anthropic",
            variant: null,
            errorName: error.name,
            errorMessage: error.message,
            time: _messageTime(message.timestamp),
          ).toJson(),
        ),
      ];
    }
    // Counted before any filtering so a skipped block still occupies its
    // ordinal, exactly as it does in the stream and the transcript.
    final firstBlockIndex = _assistantBlockCounts[messageId] ?? 0;
    _assistantBlockCounts[messageId] = firstBlockIndex + mapped.length;
    if (_content.containsInternalCommandOutput(blocks: mapped)) return const [];
    final parts = [
      for (var offset = 0; offset < mapped.length; offset++)
        _content.mapPart(
          block: mapped[offset],
          index: firstBlockIndex + offset,
          sessionId: sessionId,
          messageId: messageId,
        ),
    ];
    if (!parts.any((part) => part.type.isVisible)) return const [];
    _announcedMessageIds[sessionId] = messageId;
    final events = <BridgeSseEvent>[
      BridgeSseMessageUpdated(
        info: _assistantMessage(
          sessionId: sessionId,
          messageId: messageId,
          time: _messageTime(message.timestamp),
        ).toJson(),
      ),
    ];
    for (var offset = 0; offset < mapped.length; offset++) {
      final index = firstBlockIndex + offset;
      final part = switch (mapped[offset]) {
        ClaudeMappedToolUseContentBlock(:final id, :final name, :final input) =>
          _tools
              .upsertCompleteBlock(
                sessionId: sessionId,
                messageId: messageId,
                blockIndex: index,
                toolId: id,
                name: name,
                input: input,
              )
              .toPart(),
        _ => parts[offset],
      };
      if (part == null) continue;
      if (_streamedBlocks[messageId]?.contains(index) ?? false) {
        _completedStreamedParts.putIfAbsent(messageId, () => <int, PluginMessagePart>{})[index] = part;
      } else {
        events.add(BridgeSseMessagePartUpdated(part: part));
      }
    }
    return events;
  }

  List<BridgeSseEvent> _mapUser({
    required String sessionId,
    required ClaudeUserMessage message,
    required String? promptId,
  }) {
    final mapped = _content.map(content: message.message["content"]);
    if (_content.containsInternalCommandOutput(blocks: mapped)) return const [];
    final results = mapped.whereType<ClaudeMappedToolResultContentBlock>().toList();
    if (results.isNotEmpty) {
      // The frame-level typed result belongs to the frame's one tool result;
      // a frame carrying several cannot attribute it.
      final typedResult = results.length == 1 ? message.toolUseResult : const ClaudeToolUseResultAbsent();
      final events = <BridgeSseEvent>[];
      for (final result in results) {
        final tool = _tools.complete(
          sessionId: sessionId,
          toolId: result.toolUseId,
          output: result.output,
          isError: result.isError,
          attachments: result.attachments,
          result: typedResult,
        );
        if (tool == null) continue;
        events.addAll(_partEvents(tool: tool));
        if (tool.sessionDiffRequired) events.add(BridgeSseSessionDiff(sessionID: sessionId));
        if (tool.todoRefreshRequired) events.add(BridgeSseTodoUpdated(sessionID: sessionId));
      }
      return events;
    }
    if (mapped.whereType<ClaudeMappedTaskNotificationContentBlock>().firstOrNull case final block?) {
      final events = _applyTaskNotification(sessionId: sessionId, notification: block.notification);
      if (events != null) return events;
    }

    final messageId = _nonEmptyString(message.uuid);
    if (messageId == null) return const [];
    // Replayed stdin turns echo the exact execution payload, so the
    // bridge-owned worktree context is stripped the same way the transcript
    // history path strips it.
    final parts = _content.mapParts(
      content: _content.visibleUserContent(content: message.message["content"]),
      sessionId: sessionId,
      messageId: messageId,
    );
    if (!parts.any((part) => part.type.isVisible)) return const [];
    final events = [
      BridgeSseMessageUpdated(
        info: PluginMessage.user(
          id: messageId,
          sessionID: sessionId,
          agent: null,
          time: _messageTime(message.timestamp),
          promptId: promptId,
        ).toJson(),
      ),
      for (final part in parts) BridgeSseMessagePartUpdated(part: part),
    ];
    return events;
  }

  List<BridgeSseEvent> _mapTaskStarted({
    required ClaudeTaskStartedMessage message,
  }) {
    final toolUseId = message.toolUseId;
    final taskId = message.taskId;
    if (toolUseId == null || taskId == null) return const [];
    return _partEvents(
      tool: _tools.taskStarted(toolUseId: toolUseId, taskId: taskId),
    );
  }

  List<BridgeSseEvent> _mapTaskNotification({
    required ClaudeTaskNotificationMessage message,
  }) {
    final toolUseId = message.toolUseId;
    final taskId = message.taskId;
    if (toolUseId == null || taskId == null) return const [];
    return _partEvents(
      tool: _tools.taskNotified(
        toolUseId: toolUseId,
        taskId: taskId,
        status: message.status,
        summary: message.summary,
        result: null,
      ),
    );
  }

  /// Finalizes the task a `<task-notification>` user text names, hiding the
  /// text; null when it names no task this session knows, so the caller
  /// renders it as ordinary user text.
  List<BridgeSseEvent>? _applyTaskNotification({
    required String sessionId,
    required ClaudeTaskNotification notification,
  }) {
    final tool = _tools.taskNotified(
      toolUseId: notification.toolUseId,
      taskId: notification.taskId,
      status: notification.status,
      summary: notification.summary,
      result: notification.result,
    );
    return tool == null ? null : _partEvents(tool: tool);
  }

  List<BridgeSseEvent> _mapRetry({
    required String sessionId,
    required ClaudeApiRetryMessage message,
    required DateTime now,
  }) {
    final attempt = message.attempt;
    final delay = message.retryDelayMs;
    if (attempt == null || delay == null) return const [];
    return [
      BridgeSseSessionStatus(
        sessionID: sessionId,
        status: shared.SessionStatus.retry(
          attempt: attempt,
          message: _retryMessage(message),
          next: now.millisecondsSinceEpoch + delay,
        ).toJson(),
      ),
    ];
  }

  List<BridgeSseEvent> _mapResult({
    required String sessionId,
    required ClaudeResultMessage message,
  }) {
    if (!message.isError && message.subtype == ClaudeResultSubtype.success && message.permissionDenials.isEmpty) {
      return const [];
    }
    final mappedApiError = _mappedApiErrorSessions.remove(sessionId);
    if (mappedApiError && message.isError) return const [];
    final messageId = _nonEmptyString(message.uuid);
    if (messageId == null) return const [];
    final error = _resultError(message);
    return [
      BridgeSseMessageUpdated(
        info: PluginMessage.error(
          id: messageId,
          sessionID: sessionId,
          agent: "claude",
          modelID: _models[sessionId],
          providerID: "anthropic",
          variant: null,
          errorName: error.name,
          errorMessage: error.message,
          time: null,
        ).toJson(),
      ),
    ];
  }

  PluginMessage _assistantMessage({
    required String sessionId,
    required String messageId,
    PluginMessageTime? time,
  }) => PluginMessage.assistant(
    id: messageId,
    sessionID: sessionId,
    agent: "claude",
    modelID: _models[sessionId],
    providerID: "anthropic",
    variant: null,
    sender: PluginMessageSender.agent,
    time: time,
  );

  List<BridgeSseEvent> _announceAssistant({required String sessionId, required String messageId}) {
    if (_announcedMessageIds[sessionId] == messageId) return const [];
    _announcedMessageIds[sessionId] = messageId;
    return [
      BridgeSseMessageUpdated(
        info: _assistantMessage(sessionId: sessionId, messageId: messageId).toJson(),
      ),
    ];
  }

  /// The part update for [tool], wrapped in the child-session lifecycle a task
  /// implies: `session.created` + busy the first time its sub-agent id is
  /// known, and idle once it is terminal. Order matters — the bridge binds the
  /// child on `created` before it translates the part's `childSessionID`.
  List<BridgeSseEvent> _partEvents({required ClaudeTrackedTool? tool}) {
    final part = tool?.toPart();
    // Children of children are flattened under the root: one directory, one
    // parent, one place to look for them.
    final root = tool == null ? null : _rootOf(tool.sessionId);
    final directory = root == null ? null : _directories[root];
    if (tool is! ClaudeTrackedTask || tool.childSessionId == null || root == null || directory == null) {
      return part == null ? const [] : [BridgeSseMessagePartUpdated(part: part)];
    }
    final childId = tool.childSessionId;
    final terminal = tool.state.status.isTerminal;
    final announced = _announcedChildren.putIfAbsent(root, () => {});
    final busy = _busyChildren.putIfAbsent(root, () => {});
    final events = <BridgeSseEvent>[];
    if (childId != null && announced.add(childId)) {
      _roots[childId] = root;
      events.add(
        BridgeSseSessionCreated(
          info: PluginSession(
            id: childId,
            projectID: directory,
            directory: directory,
            parentID: root,
            title: switch (tool.input) {
              {"description": final String description} => description,
              _ => null,
            },
            time: null,
          ).toJson(),
        ),
      );
      if (!terminal) busy.add(childId);
      events.add(_childStatus(childId: childId, busy: !terminal));
    } else if (childId != null && !terminal && busy.add(childId)) {
      // Claude can resume an already-announced agent after it stopped. Restore
      // the child to busy before publishing the reopened subtask part.
      events.add(_childStatus(childId: childId, busy: true));
    }
    if (part != null) events.add(BridgeSseMessagePartUpdated(part: part));
    if (childId != null && terminal && busy.remove(childId)) events.add(_childStatus(childId: childId, busy: false));
    return events;
  }
}

PluginMessagePart _textPart({
  required String sessionId,
  required String messageId,
  required int index,
  required PluginMessagePartType type,
  required String text,
}) => switch (type) {
  PluginMessagePartType.text => PluginMessagePart.fromText(
    id: "$messageId-block-$index",
    sessionID: sessionId,
    messageID: messageId,
    text: text,
  ),
  PluginMessagePartType.reasoning => PluginMessagePart.fromThinking(
    id: "$messageId-block-$index",
    sessionID: sessionId,
    messageID: messageId,
    text: text,
  ),
  _ => throw ArgumentError.value(type, "type"),
};

BridgeSseSessionStatus _childStatus({required String childId, required bool busy}) => BridgeSseSessionStatus(
  sessionID: childId,
  status: (busy ? const shared.SessionStatus.busy() : const shared.SessionStatus.idle()).toJson(),
);

Map<String, Object?>? _mapOrNull(Object? value) => value is Map ? value.cast<String, Object?>() : null;

String? _nonEmptyString(Object? value) => value is String && value.isNotEmpty ? value : null;

String? _realModel({required String? model}) {
  final normalized = _nonEmptyString(model);
  return normalized == "<synthetic>" ? null : normalized;
}

PluginMessageTime? _messageTime(DateTime? timestamp) =>
    timestamp == null ? null : PluginMessageTime(created: timestamp.millisecondsSinceEpoch, completed: null);

String _retryMessage(ClaudeApiRetryMessage message) => message.rawError ?? "Claude Code is retrying the request.";

({String name, String message}) _resultError(ClaudeResultMessage result) {
  if (!result.isError && result.subtype == ClaudeResultSubtype.success && result.permissionDenials.isNotEmpty) {
    return (name: "permission_denied", message: "Claude Code denied a tool without requesting permission.");
  }
  final fallback = _resultErrorFallback(result);
  final rawError = result.errors.isNotEmpty ? result.errors.join("\n") : result.result;
  return rawError == null ? fallback : (name: fallback.name, message: rawError);
}

({String name, String message}) _resultErrorFallback(ClaudeResultMessage result) {
  if (result.apiErrorStatus == 401 || result.apiErrorStatus == 403) {
    return (name: claudeApiErrorName(status: result.apiErrorStatus), message: "Claude Code authentication failed.");
  }
  return switch (result.terminalReason) {
    ClaudeTerminalReason.budgetExhausted => (
      name: "budget_exhausted",
      message: "Claude Code reached the configured budget.",
    ),
    ClaudeTerminalReason.maxTurns => (
      name: "max_turns",
      message: "Claude Code reached the maximum number of turns.",
    ),
    ClaudeTerminalReason.structuredOutputRetryExhausted => (
      name: "structured_output_failed",
      message: "Claude Code could not produce valid structured output.",
    ),
    ClaudeTerminalReason.apiError => (
      name: claudeApiErrorName(status: result.apiErrorStatus),
      message: result.apiErrorStatus == null
          ? "Claude Code could not complete the API request."
          : "Claude Code could not complete the API request (HTTP ${result.apiErrorStatus}).",
    ),
    ClaudeTerminalReason.promptTooLong => (
      name: "prompt_too_long",
      message: "The prompt is too long for Claude Code.",
    ),
    _ => (name: "claude_error", message: "Claude Code could not complete the request."),
  };
}
