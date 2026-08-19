import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart" as shared;

import "api/models/claude_stream_message.dart";
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
  final Map<String, ({String promptId, void Function() onConsumed})> _expectedUserEcho = {};

  void beginTurn({required String sessionId}) {
    _messageIds.remove(sessionId);
    _announcedMessageIds.remove(sessionId);
    // A leftover expectation belongs to a turn whose echo never arrived
    // (interrupted between stdin write and CLI read); the new turn must not
    // inherit it.
    _expectedUserEcho.remove(sessionId);
    _clearStreamedMessages(sessionId: sessionId);
    _tools.beginTurn(sessionId: sessionId);
  }

  /// Drops a pending echo expectation whose turn was aborted, so a late
  /// buffered frame cannot be stamped with the aborted prompt id.
  void clearExpectedUserEcho({required String sessionId}) {
    _expectedUserEcho.remove(sessionId);
  }

  /// Declares that the session's next replayed stdin echo fulfills
  /// [promptId]: the echoed user message carries it, and [onConsumed] runs
  /// after the message events are built (its queue update trails them).
  ///
  /// Dispatch is serialized per session, so at most one expectation is live;
  /// a new dispatch overwrites the previous turn's expectation when its echo
  /// never arrived (interrupt between stdin write and CLI read).
  void expectUserEcho({
    required String sessionId,
    required String promptId,
    required void Function() onConsumed,
  }) {
    _expectedUserEcho[sessionId] = (promptId: promptId, onConsumed: onConsumed);
  }

  void forgetSession({required String sessionId}) {
    _messageIds.remove(sessionId);
    _announcedMessageIds.remove(sessionId);
    _models.remove(sessionId);
    _expectedUserEcho.remove(sessionId);
    _clearStreamedMessages(sessionId: sessionId);
    _tools.forgetSession(sessionId: sessionId);
  }

  void _clearStreamedMessages({required String sessionId}) {
    final messageIds = _streamedMessageIds.remove(sessionId);
    if (messageIds == null) return;
    for (final messageId in messageIds) {
      _streamedBlocks.remove(messageId);
      _completedStreamedParts.remove(messageId);
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
      message: _retryMessage(message.error),
      next: now.millisecondsSinceEpoch + delay,
    );
  }

  List<BridgeSseEvent> map({required ClaudeStreamMessage message, DateTime? now}) {
    if (message.sessionId case final sessionId? when sessionId.isNotEmpty) {
      if (message
          case ClaudeAssistantMessage(parentToolUseId: final String _) ||
              ClaudeUserMessage(parentToolUseId: final String _) ||
              ClaudeStreamEventMessage(parentToolUseId: final String _)) {
        return const [];
      }
      return switch (message) {
        ClaudeStreamEventMessage() => _mapStream(sessionId: sessionId, message: message),
        ClaudeAssistantMessage() => _mapAssistant(sessionId: sessionId, message: message),
        ClaudeUserMessage() => _mapUser(sessionId: sessionId, message: message),
        ClaudeApiRetryMessage() => _mapRetry(sessionId: sessionId, message: message, now: now ?? DateTime.now()),
        ClaudeResultMessage() => _mapResult(sessionId: sessionId, message: message),
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
      ClaudeMappedToolUseContentBlock(:final id, :final name, :final input) => _toolPart(
        sessionId: sessionId,
        tool: _tools.start(
          sessionId: sessionId,
          messageId: messageId,
          blockIndex: index,
          toolId: id,
          name: name,
          input: input,
        ),
      ),
      ClaudeMappedToolResultContentBlock() ||
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
        final tool = _tools.appendInput(
          sessionId: sessionId,
          messageId: messageId,
          blockIndex: index,
          partialJson: partialJson,
        );
        return tool == null
            ? const []
            : [
                BridgeSseMessagePartUpdated(
                  part: _toolPart(sessionId: sessionId, tool: tool),
                ),
              ];
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
    final tool = _tools.stopInput(sessionId: sessionId, messageId: messageId, blockIndex: index);
    final completed = _completedStreamedParts[messageId]?.remove(index);
    return [
      if (tool != null)
        BridgeSseMessagePartUpdated(
          part: _toolPart(sessionId: sessionId, tool: tool),
        ),
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
    if (_realModel(model: message.model) case final model?) _models[sessionId] = model;
    final mapped = _content.map(content: message.message["content"]);
    if (_content.containsInternalCommandOutput(blocks: mapped)) return const [];
    final parts = _content.mapParts(content: message.message["content"], sessionId: sessionId, messageId: messageId);
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
    for (var index = 0; index < mapped.length; index++) {
      final part = switch (mapped[index]) {
        ClaudeMappedToolUseContentBlock(:final id, :final name, :final input) => _toolPart(
          sessionId: sessionId,
          tool: _tools.upsertCompleteBlock(
            sessionId: sessionId,
            messageId: messageId,
            blockIndex: index,
            toolId: id,
            name: name,
            input: input,
          ),
        ),
        _ => parts[index],
      };
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
  }) {
    final mapped = _content.map(content: message.message["content"]);
    if (_content.containsInternalCommandOutput(blocks: mapped)) return const [];
    final results = mapped.whereType<ClaudeMappedToolResultContentBlock>().toList();
    if (results.isNotEmpty) {
      final events = <BridgeSseEvent>[];
      for (final result in results) {
        final tool = _tools.complete(
          sessionId: sessionId,
          toolId: result.toolUseId,
          output: result.output,
          isError: result.isError,
          attachments: result.attachments,
        );
        if (tool == null) continue;
        events.add(
          BridgeSseMessagePartUpdated(
            part: _toolPart(sessionId: sessionId, tool: tool),
          ),
        );
        if (tool.sessionDiffRequired) events.add(BridgeSseSessionDiff(sessionID: sessionId));
        if (tool.todoRefreshRequired) events.add(BridgeSseTodoUpdated(sessionID: sessionId));
      }
      return events;
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
    final expectation = _expectedUserEcho.remove(sessionId);
    final events = [
      BridgeSseMessageUpdated(
        info: PluginMessage.user(
          id: messageId,
          sessionID: sessionId,
          agent: null,
          time: _messageTime(message.timestamp),
          promptId: expectation?.promptId,
        ).toJson(),
      ),
      for (final part in parts) BridgeSseMessagePartUpdated(part: part),
    ];
    expectation?.onConsumed();
    return events;
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
          message: _retryMessage(message.error),
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
}

PluginMessagePart _textPart({
  required String sessionId,
  required String messageId,
  required int index,
  required PluginMessagePartType type,
  required String text,
}) => PluginMessagePart(
  id: "$messageId-block-$index",
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
  attachment: null,
);

PluginMessagePart _toolPart({required String sessionId, required ClaudeTrackedTool tool}) => PluginMessagePart(
  id: tool.id,
  sessionID: sessionId,
  messageID: tool.messageId,
  type: PluginMessagePartType.tool,
  text: null,
  tool: tool.name,
  state: tool.state,
  prompt: null,
  description: null,
  agent: null,
  agentName: null,
  attempt: null,
  retryError: null,
  attachment: null,
);

Map<String, Object?>? _mapOrNull(Object? value) => value is Map ? value.cast<String, Object?>() : null;

String? _nonEmptyString(Object? value) => value is String && value.isNotEmpty ? value : null;

String? _realModel({required String? model}) {
  final normalized = _nonEmptyString(model);
  return normalized == "<synthetic>" ? null : normalized;
}

PluginMessageTime? _messageTime(DateTime? timestamp) =>
    timestamp == null ? null : PluginMessageTime(created: timestamp.millisecondsSinceEpoch, completed: null);

String _retryMessage(ClaudeAssistantError error) => switch (error) {
  ClaudeAssistantError.authenticationFailed ||
  ClaudeAssistantError.oauthOrgNotAllowed => "Claude Code is retrying after an authentication failure.",
  ClaudeAssistantError.billingError => "Claude Code is retrying after a billing failure.",
  ClaudeAssistantError.rateLimit => "Claude Code is retrying after a rate limit.",
  ClaudeAssistantError.overloaded => "Claude Code is retrying because the service is overloaded.",
  ClaudeAssistantError.modelNotFound => "Claude Code is retrying with the selected model.",
  ClaudeAssistantError.maxOutputTokens => "Claude Code is retrying after reaching the output limit.",
  ClaudeAssistantError.invalidRequest ||
  ClaudeAssistantError.serverError ||
  ClaudeAssistantError.unknown => "Claude Code is retrying the request.",
};

({String name, String message}) _resultError(ClaudeResultMessage result) {
  if (!result.isError && result.subtype == ClaudeResultSubtype.success && result.permissionDenials.isNotEmpty) {
    return (name: "permission_denied", message: "Claude Code denied a tool without requesting permission.");
  }
  if (result.apiErrorStatus == 401 || result.apiErrorStatus == 403) {
    return (name: "authentication_failed", message: "Claude Code authentication failed.");
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
      name: "api_error",
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
