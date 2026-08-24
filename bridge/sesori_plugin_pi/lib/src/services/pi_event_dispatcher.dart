import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "../api/models/pi_assistant_delta.dart";
import "../api/models/pi_event.dart";
import "../api/models/pi_session_history_dto.dart";
import "../models/pi_assistant_stop_reason.dart";
import "../repositories/mappers/pi_history_mapper.dart";
import "../repositories/mappers/pi_message_identity_builder.dart";
import "../trackers/pi_message_identity_tracker.dart";
import "../trackers/pi_tool_tracker.dart";

final class PiEventDispatcher({
  required final PiHistoryMapper historyMapper,
  required final PiMessageIdentityTracker identityTracker,
  required final PiToolTracker toolTracker,
}) {
  final PiHistoryMapper _historyMapper = historyMapper;
  final PiMessageIdentityTracker _identityTracker = identityTracker;
  final PiToolTracker _tools = toolTracker;
  final Map<String, _SessionState> _sessions = {};

  void registerPrompt({
    required String sessionId,
    required String promptId,
    required String? executionText,
    required String? userVisibleText,
  }) {
    _session(sessionId).pendingPrompts.add(
      _PendingPrompt(
        promptId: promptId,
        executionText: executionText,
        userVisibleText: userVisibleText,
      ),
    );
  }

  void cancelPrompt({required String sessionId, required String promptId}) {
    _sessions[sessionId]?.pendingPrompts.removeWhere((prompt) => prompt.promptId == promptId);
  }

  PluginMessageWithParts? activeCompactionMessage({required String sessionId}) {
    final state = _sessions[sessionId];
    final messageId = state?.compactionMessageId;
    if (messageId == null) return null;
    return _historyMapper.mapRunningCompaction(sessionId: sessionId, messageId: messageId);
  }

  List<BridgeSseEvent> clearCompaction({required String sessionId}) {
    final state = _sessions[sessionId];
    final messageId = state?.compactionMessageId;
    if (state == null || messageId == null) return const [];
    state
      ..compactionMessageId = null
      ..identities.releaseCompaction();
    return [BridgeSseMessageRemoved(sessionID: sessionId, messageID: messageId)];
  }

  void forgetSession({required String sessionId}) {
    _sessions.remove(sessionId);
    _identityTracker.forgetSession(sessionId: sessionId);
    _tools.forgetSession(sessionId: sessionId);
  }

  PluginSessionStatus? sessionStatusFor({required PiEvent event, DateTime? now}) => switch (event) {
    PiAgentStartEvent() ||
    PiAutoRetryEndEvent(success: true) ||
    PiSummarizationRetryAttemptStartEvent() ||
    PiCompactionStartEvent() => const PluginSessionStatus.busy(),
    PiAgentSettledEvent() => const PluginSessionStatus.idle(),
    PiAutoRetryStartEvent(:final attempt, :final delayMs) => _retryStatus(
      attempt: attempt,
      delayMs: delayMs,
      now: now ?? DateTime.now(),
    ),
    PiSummarizationRetryScheduledEvent(:final attempt, :final delayMs) => _retryStatus(
      attempt: attempt,
      delayMs: delayMs,
      now: now ?? DateTime.now(),
    ),
    _ => null,
  };

  List<BridgeSseEvent> map({required String sessionId, required PiEvent event, DateTime? now}) => switch (event) {
    PiAgentStartEvent() => _status(sessionId: sessionId, event: event, now: now),
    PiAgentSettledEvent() => [
      ..._status(sessionId: sessionId, event: event, now: now),
      BridgeSseSessionIdle(sessionID: sessionId),
    ],
    PiMessageStartEvent(:final message) => _messageStart(sessionId: sessionId, raw: message),
    PiMessageUpdateEvent(:final delta) => _messageUpdate(sessionId: sessionId, delta: delta),
    PiMessageEndEvent(:final message) => _messageEnd(sessionId: sessionId, raw: message),
    PiToolExecutionStartEvent(:final toolCallId, :final toolName) => _toolRunning(
      sessionId: sessionId,
      toolCallId: toolCallId,
      toolName: toolName,
      result: const {},
    ),
    PiToolExecutionUpdateEvent(:final toolCallId, :final toolName, :final partialResult) => _toolRunning(
      sessionId: sessionId,
      toolCallId: toolCallId,
      toolName: toolName,
      result: partialResult,
    ),
    PiToolExecutionEndEvent(:final toolCallId, :final toolName, :final result, :final isError) => _toolEnd(
      sessionId: sessionId,
      toolCallId: toolCallId,
      toolName: toolName,
      result: result,
      isError: isError,
    ),
    PiAutoRetryStartEvent() ||
    PiSummarizationRetryScheduledEvent() => _status(sessionId: sessionId, event: event, now: now),
    PiAutoRetryEndEvent(:final success, :final attempt, :final finalError) when !success => _retryEnd(
      sessionId: sessionId,
      attempt: attempt,
      finalError: finalError,
    ),
    PiAutoRetryEndEvent() ||
    PiSummarizationRetryAttemptStartEvent() => _status(sessionId: sessionId, event: event, now: now),
    PiCompactionStartEvent() => _compactionStart(sessionId: sessionId, event: event, now: now),
    PiCompactionEndEvent(:final reason, :final aborted, :final willRetry, :final errorMessage) => _compactionEnd(
      sessionId: sessionId,
      reason: reason,
      aborted: aborted,
      willRetry: willRetry,
      errorMessage: errorMessage,
    ),
    PiExtensionErrorEvent(:final extensionPath, event: final operation, :final error) => _extensionError(
      extensionPath: extensionPath,
      operation: operation,
      error: error,
    ),
    PiEntryAppendedEvent(:final entry) => _entryAppended(sessionId: sessionId, raw: entry),
    PiTurnStartEvent() => _turnStart(sessionId: sessionId),
    PiAgentEndEvent() ||
    PiTurnEndEvent() ||
    PiBashExecutionUpdateEvent() ||
    PiQueueUpdateEvent() ||
    PiSessionInfoChangedEvent() ||
    PiThinkingLevelChangedEvent() ||
    PiSummarizationRetryFinishedEvent() ||
    PiUnknownEvent() => const [],
  };

  List<BridgeSseEvent> _messageStart({required String sessionId, required Map<String, Object?> raw}) {
    final message = _historyMapper.decodeAssistantMessage(raw: raw);
    if (message == null) return const [];
    final state = _session(sessionId);
    state.clearMessage();
    state
      ..messageId = state.identities.next(role: PiMessageIdentityRole.assistant, timestamp: message.timestamp)
      ..message = message
      ..announced = false;
    return const [];
  }

  List<BridgeSseEvent> _entryAppended({required String sessionId, required Map<String, Object?> raw}) {
    final entry = _historyMapper.decodeCustomMessageEntry(raw: raw);
    if (entry == null) return const [];
    final state = _session(sessionId);
    final messageId = state.identities.nextTopLevelCustomMessage();
    final mapped = _historyMapper.mapCustomMessageEntry(
      sessionId: sessionId,
      messageId: messageId,
      entry: entry,
    );
    return mapped == null
        ? const []
        : [
            BridgeSseMessageUpdated(info: mapped.info.toJson()),
            for (final part in mapped.parts) BridgeSseMessagePartUpdated(part: part),
          ];
  }

  List<BridgeSseEvent> _messageUpdate({required String sessionId, required PiAssistantDelta delta}) {
    final state = _session(sessionId);
    final messageId = state.messageId;
    if (messageId == null) return const [];
    return switch (delta) {
      PiTextStartDelta(:final contentIndex) => _startTextPart(
        sessionId: sessionId,
        state: state,
        contentIndex: contentIndex,
        type: PluginMessagePartType.text,
      ),
      PiThinkingStartDelta(:final contentIndex) => _startTextPart(
        sessionId: sessionId,
        state: state,
        contentIndex: contentIndex,
        type: PluginMessagePartType.reasoning,
      ),
      PiTextDelta(:final contentIndex, :final delta) => _textDelta(
        sessionId: sessionId,
        state: state,
        contentIndex: contentIndex,
        delta: delta,
        type: PluginMessagePartType.text,
      ),
      PiThinkingDelta(:final contentIndex, :final delta) => _textDelta(
        sessionId: sessionId,
        state: state,
        contentIndex: contentIndex,
        delta: delta,
        type: PluginMessagePartType.reasoning,
      ),
      PiTextEndDelta(:final contentIndex, :final content) => _finishTextPart(
        sessionId: sessionId,
        state: state,
        contentIndex: contentIndex,
        content: content,
        type: PluginMessagePartType.text,
      ),
      PiThinkingEndDelta(:final contentIndex, :final content) => _finishTextPart(
        sessionId: sessionId,
        state: state,
        contentIndex: contentIndex,
        content: content,
        type: PluginMessagePartType.reasoning,
      ),
      PiToolCallEndDelta(:final contentIndex, :final toolCall) => _toolCall(
        sessionId: sessionId,
        state: state,
        contentIndex: contentIndex,
        toolCall: toolCall,
      ),
      PiMessageStartDelta() ||
      PiToolCallStartDelta() ||
      PiToolCallDelta() ||
      PiAssistantDoneDelta() ||
      PiAssistantErrorDelta() ||
      PiUnknownDelta() => const [],
    };
  }

  List<BridgeSseEvent> _messageEnd({required String sessionId, required Map<String, Object?> raw}) {
    final message = _historyMapper.decodeAssistantMessage(raw: raw);
    if (message == null) {
      return raw["role"] == "assistant"
          ? _dropMalformedAssistantEnd(sessionId: sessionId)
          : _nonAssistantEnd(sessionId: sessionId, raw: raw);
    }
    final state = _session(sessionId);
    final messageId =
        state.messageId ?? state.identities.next(role: PiMessageIdentityRole.assistant, timestamp: message.timestamp);
    final mapped = _historyMapper.mapAssistantMessage(sessionId: sessionId, messageId: messageId, message: message);
    final parts = <PluginMessagePart>[];
    var sessionDiffRequired = false;
    for (final part in mapped.parts) {
      if (part.type != PluginMessagePartType.tool) {
        parts.add(part);
        continue;
      }
      final tracked = _tools.pending(
        sessionId: sessionId,
        messageId: messageId,
        toolId: part.id,
        name: part.tool ?? "tool",
      );
      if (tracked == null) {
        parts.add(part);
        continue;
      }
      final terminal =
          message.stopReason == PiAssistantStopReason.error || message.stopReason == PiAssistantStopReason.aborted
          ? _tools.complete(
              sessionId: sessionId,
              toolId: tracked.id,
              name: tracked.name,
              state: const PluginToolState(
                status: PluginToolStatus.error,
                title: null,
                output: null,
                error: "Pi tool call did not complete.",
                attachments: [],
              ),
            )
          : null;
      if (terminal?.sessionDiffRequired ?? false) sessionDiffRequired = true;
      parts.add(_toolPart(sessionId: sessionId, tool: terminal ?? tracked));
    }
    final removedPartIds = state.emittedPartIds.toList(growable: false);
    final announced = state.announced;
    final visible =
        parts.isNotEmpty ||
        message.stopReason == PiAssistantStopReason.error ||
        message.stopReason == PiAssistantStopReason.aborted;
    state.clearMessage();
    if (!visible) {
      return [
        if (announced) BridgeSseMessageRemoved(sessionID: sessionId, messageID: messageId),
      ];
    }
    return [
      BridgeSseMessageUpdated(info: mapped.info.toJson()),
      for (final partId in removedPartIds)
        BridgeSseMessagePartRemoved(sessionID: sessionId, messageID: messageId, partID: partId),
      for (final part in parts) BridgeSseMessagePartUpdated(part: part),
      if (sessionDiffRequired) BridgeSseSessionDiff(sessionID: sessionId),
    ];
  }

  List<BridgeSseEvent> _dropMalformedAssistantEnd({required String sessionId}) {
    final state = _sessions[sessionId];
    final messageId = state?.messageId;
    final announced = state?.announced ?? false;
    _tools.beginTurn(sessionId: sessionId);
    state?.clearMessage();
    return announced && messageId != null
        ? [BridgeSseMessageRemoved(sessionID: sessionId, messageID: messageId)]
        : const [];
  }

  List<BridgeSseEvent> _bashEnd({required String sessionId, required Map<String, Object?> raw}) {
    final message = _historyMapper.decodeBashExecutionMessage(raw: raw);
    if (message == null) return const [];
    final state = _session(sessionId);
    final messageId = state.identities.next(
      role: PiMessageIdentityRole.bashExecution,
      timestamp: message.timestamp,
    );
    final mapped = _historyMapper.mapBashExecution(sessionId: sessionId, messageId: messageId, message: message);
    return [
      BridgeSseMessageUpdated(info: mapped.info.toJson()),
      for (final part in mapped.parts) BridgeSseMessagePartUpdated(part: part),
    ];
  }

  List<BridgeSseEvent> _nonAssistantEnd({required String sessionId, required Map<String, Object?> raw}) {
    final user = _userEnd(sessionId: sessionId, raw: raw);
    if (user.isNotEmpty) return user;
    final bash = _bashEnd(sessionId: sessionId, raw: raw);
    return bash.isNotEmpty ? bash : _customEnd(sessionId: sessionId, raw: raw);
  }

  List<BridgeSseEvent> _userEnd({required String sessionId, required Map<String, Object?> raw}) {
    final message = _historyMapper.decodeUserMessage(raw: raw);
    if (message == null) return const [];
    final state = _session(sessionId);
    final textContent = message.content.whereType<PiTextContentDto>().singleOrNull;
    final isAttachmentOnlyMessage =
        message.content.isNotEmpty && message.content.every((content) => content is PiImageContentDto);
    final correlationIndex = state.pendingPrompts.indexWhere(
      (prompt) =>
          textContent?.text == prompt.executionText ||
          ((prompt.executionText?.isEmpty ?? false) && isAttachmentOnlyMessage),
    );
    final correlation = correlationIndex == -1 ? null : state.pendingPrompts.removeAt(correlationIndex);
    final messageId = state.identities.next(role: PiMessageIdentityRole.user, timestamp: message.timestamp);
    final mapped = _historyMapper.mapUserMessage(
      sessionId: sessionId,
      messageId: messageId,
      message: message,
      exactText: correlation?.userVisibleText,
      promptId: correlation?.promptId,
    );
    if (mapped == null) return const [];
    return [
      BridgeSseMessageUpdated(info: mapped.info.toJson()),
      for (final part in mapped.parts) BridgeSseMessagePartUpdated(part: part),
    ];
  }

  List<BridgeSseEvent> _customEnd({required String sessionId, required Map<String, Object?> raw}) {
    final message = _historyMapper.decodeCustomMessage(raw: raw);
    if (message == null) return const [];
    final state = _session(sessionId);
    final messageId = state.identities.next(
      role: PiMessageIdentityRole.custom,
      timestamp: message.timestamp,
    );
    final mapped = _historyMapper.mapCustomMessage(
      sessionId: sessionId,
      messageId: messageId,
      message: message,
    );
    if (mapped == null) return const [];
    return [
      BridgeSseMessageUpdated(info: mapped.info.toJson()),
      for (final part in mapped.parts) BridgeSseMessagePartUpdated(part: part),
    ];
  }

  List<BridgeSseEvent> _startTextPart({
    required String sessionId,
    required _SessionState state,
    required int? contentIndex,
    required PluginMessagePartType type,
  }) {
    final messageId = state.messageId;
    if (messageId == null || contentIndex == null || contentIndex < 0) return const [];
    final key = (contentIndex: contentIndex, type: type);
    if (!state.startedParts.add(key)) return const [];
    state.emittedPartIds.add(_blockId(messageId: messageId, contentIndex: contentIndex));
    return [
      ..._announce(sessionId: sessionId, state: state),
      BridgeSseMessagePartUpdated(
        part: _textPart(
          sessionId: sessionId,
          messageId: messageId,
          contentIndex: contentIndex,
          type: type,
          text: "",
        ),
      ),
    ];
  }

  List<BridgeSseEvent> _textDelta({
    required String sessionId,
    required _SessionState state,
    required int? contentIndex,
    required String? delta,
    required PluginMessagePartType type,
  }) {
    final messageId = state.messageId;
    if (messageId == null || contentIndex == null || contentIndex < 0 || delta == null || delta.isEmpty) {
      return const [];
    }
    return [
      ..._startTextPart(sessionId: sessionId, state: state, contentIndex: contentIndex, type: type),
      BridgeSseMessagePartDelta(
        sessionID: sessionId,
        messageID: messageId,
        partID: _blockId(messageId: messageId, contentIndex: contentIndex),
        field: "text",
        delta: delta,
      ),
    ];
  }

  List<BridgeSseEvent> _finishTextPart({
    required String sessionId,
    required _SessionState state,
    required int? contentIndex,
    required String? content,
    required PluginMessagePartType type,
  }) {
    final messageId = state.messageId;
    if (messageId == null || contentIndex == null || contentIndex < 0 || content == null) return const [];
    state.startedParts.add((contentIndex: contentIndex, type: type));
    state.emittedPartIds.add(_blockId(messageId: messageId, contentIndex: contentIndex));
    return [
      ..._announce(sessionId: sessionId, state: state),
      BridgeSseMessagePartUpdated(
        part: _textPart(
          sessionId: sessionId,
          messageId: messageId,
          contentIndex: contentIndex,
          type: type,
          text: content,
        ),
      ),
    ];
  }

  List<BridgeSseEvent> _toolCall({
    required String sessionId,
    required _SessionState state,
    required int? contentIndex,
    required Map<String, Object?> toolCall,
  }) {
    if (contentIndex == null || contentIndex < 0) return const [];
    final messageId = state.messageId;
    final decoded = _historyMapper.decodeToolCall(raw: toolCall);
    if (messageId == null || decoded == null) return const [];
    final tool = _tools.pending(
      sessionId: sessionId,
      messageId: messageId,
      toolId: decoded.id,
      name: decoded.name,
    );
    if (tool != null) state.emittedPartIds.add(tool.id);
    return tool == null
        ? const []
        : [
            ..._announce(sessionId: sessionId, state: state),
            BridgeSseMessagePartUpdated(
              part: _toolPart(sessionId: sessionId, tool: tool),
            ),
          ];
  }

  List<BridgeSseEvent> _toolRunning({
    required String sessionId,
    required String? toolCallId,
    required String? toolName,
    required Map<String, Object?> result,
  }) {
    if (toolCallId == null) return const [];
    final state = _historyMapper.mapLiveToolResult(
      toolCallId: toolCallId,
      toolName: toolName,
      result: result,
      isError: false,
      status: PluginToolStatus.running,
      title: null,
    );
    if (state == null) return const [];
    final tool = _tools.running(
      sessionId: sessionId,
      toolId: toolCallId,
      name: toolName,
      state: state,
    );
    return tool == null
        ? const []
        : [
            BridgeSseMessagePartUpdated(
              part: _toolPart(sessionId: sessionId, tool: tool),
            ),
          ];
  }

  List<BridgeSseEvent> _toolEnd({
    required String sessionId,
    required String? toolCallId,
    required String? toolName,
    required Map<String, Object?> result,
    required bool isError,
  }) {
    if (toolCallId == null) return const [];
    final state = _historyMapper.mapLiveToolResult(
      toolCallId: toolCallId,
      toolName: toolName,
      result: result,
      isError: isError,
      status: isError ? PluginToolStatus.error : PluginToolStatus.completed,
      title: null,
    );
    if (state == null) return const [];
    final tool = _tools.complete(
      sessionId: sessionId,
      toolId: toolCallId,
      name: toolName,
      state: state,
    );
    return tool == null
        ? const []
        : [
            BridgeSseMessagePartUpdated(
              part: _toolPart(sessionId: sessionId, tool: tool),
            ),
            if (tool.sessionDiffRequired) BridgeSseSessionDiff(sessionID: sessionId),
          ];
  }

  PluginSessionStatus? _retryStatus({
    required int? attempt,
    required int? delayMs,
    required DateTime now,
  }) {
    if (attempt == null || delayMs == null || attempt < 0 || delayMs < 0) return null;
    return PluginSessionStatus.retry(
      attempt: attempt,
      message: "Pi is retrying the provider request.",
      next: now.millisecondsSinceEpoch + delayMs,
    );
  }

  List<BridgeSseEvent> _turnStart({required String sessionId}) {
    _tools.beginTurn(sessionId: sessionId);
    return const [];
  }

  List<BridgeSseEvent> _status({required String sessionId, required PiEvent event, required DateTime? now}) {
    final status = sessionStatusFor(event: event, now: now);
    return status == null ? const [] : [BridgeSseSessionStatus(sessionID: sessionId, status: status.toJson())];
  }

  List<BridgeSseEvent> _compactionStart({
    required String sessionId,
    required PiCompactionStartEvent event,
    required DateTime? now,
  }) {
    final state = _session(sessionId);
    final messageId = state.compactionMessageId ??= state.identities.reserveCompaction();
    final mapped = _historyMapper.mapRunningCompaction(sessionId: sessionId, messageId: messageId);
    return [
      ..._status(sessionId: sessionId, event: event, now: now),
      BridgeSseMessageUpdated(info: mapped.info.toJson()),
      for (final part in mapped.parts) BridgeSseMessagePartUpdated(part: part),
    ];
  }

  List<BridgeSseEvent> _retryEnd({
    required String sessionId,
    required int? attempt,
    required String? finalError,
  }) {
    if (finalError != null) {
      Log.w(
        "[pi] provider retry failed",
        _PiRetryFailureDiagnostic(attempt: attempt, detail: finalError),
      );
    }
    return [BridgeSseSessionError(sessionID: sessionId)];
  }

  List<BridgeSseEvent> _compactionEnd({
    required String sessionId,
    required Object? reason,
    required bool aborted,
    required bool willRetry,
    required String? errorMessage,
  }) {
    if (errorMessage != null) {
      Log.w(
        "[pi] compaction failed",
        _PiCompactionFailureDiagnostic(reason: reason, detail: errorMessage),
      );
    }
    if (aborted || errorMessage != null) {
      if (willRetry) return const [];
      return [
        ...clearCompaction(sessionId: sessionId),
        BridgeSseSessionError(sessionID: sessionId),
      ];
    }
    final state = _session(sessionId);
    final messageId = state.identities.commitCompaction();
    state.compactionMessageId = null;
    final mapped = _historyMapper.mapCompaction(sessionId: sessionId, messageId: messageId);
    return [
      BridgeSseSessionCompacted(sessionID: sessionId),
      BridgeSseMessageUpdated(info: mapped.info.toJson()),
      for (final part in mapped.parts) BridgeSseMessagePartUpdated(part: part),
    ];
  }

  List<BridgeSseEvent> _extensionError({
    required String? extensionPath,
    required String? operation,
    required String? error,
  }) {
    if (error != null) {
      Log.w(
        "[pi] extension handler failed",
        _PiExtensionFailureDiagnostic(
          extensionPath: extensionPath,
          operation: operation,
          detail: error,
        ),
      );
    }
    return const [];
  }

  List<BridgeSseEvent> _announce({required String sessionId, required _SessionState state}) {
    if (state.announced) return const [];
    final messageId = state.messageId;
    final message = state.message;
    if (messageId == null || message == null) return const [];
    state.announced = true;
    final mapped = _historyMapper.mapAssistantMessage(sessionId: sessionId, messageId: messageId, message: message);
    return [BridgeSseMessageUpdated(info: mapped.info.toJson())];
  }

  _SessionState _session(String sessionId) => _sessions.putIfAbsent(
    sessionId,
    () => _SessionState(identities: _identityTracker.forSession(sessionId: sessionId)),
  );
}

final class const _PendingPrompt({
  required final String promptId,
  required final String? executionText,
  required final String? userVisibleText,
});

final class _SessionState({required final PiMessageIdentityBuilder identities}) {
  String? messageId;
  PiAssistantMessageDto? message;
  final List<_PendingPrompt> pendingPrompts = [];
  bool announced = false;
  final Set<({int contentIndex, PluginMessagePartType type})> startedParts = {};
  final Set<String> emittedPartIds = {};
  String? compactionMessageId;

  void clearMessage() {
    messageId = null;
    message = null;
    announced = false;
    startedParts.clear();
    emittedPartIds.clear();
  }
}

PluginMessagePart _textPart({
  required String sessionId,
  required String messageId,
  required int contentIndex,
  required PluginMessagePartType type,
  required String text,
}) => switch (type) {
  PluginMessagePartType.text => PluginMessagePart.fromText(
    id: _blockId(messageId: messageId, contentIndex: contentIndex),
    sessionID: sessionId,
    messageID: messageId,
    text: text,
  ),
  PluginMessagePartType.reasoning => PluginMessagePart.fromThinking(
    id: _blockId(messageId: messageId, contentIndex: contentIndex),
    sessionID: sessionId,
    messageID: messageId,
    text: text,
  ),
  _ => throw ArgumentError.value(type, "type"),
};

PluginMessagePart _toolPart({required String sessionId, required PiTrackedTool tool}) => PluginMessagePart.fromTool(
  id: tool.id,
  sessionID: sessionId,
  messageID: tool.messageId,
  tool: tool.name,
  state: tool.state,
);

String _blockId({required String messageId, required int contentIndex}) => "$messageId-block-${contentIndex + 1}";

final class const _PiCompactionFailureDiagnostic({
  required final Object? reason,
  required final String detail,
}) implements Exception {
  @override
  String toString() => "Pi compaction failed (reason: $reason): $detail";
}

final class const _PiRetryFailureDiagnostic({
  required final int? attempt,
  required final String detail,
}) implements Exception {
  @override
  String toString() => "Pi provider retry failed (attempt: $attempt): $detail";
}

final class const _PiExtensionFailureDiagnostic({
  required final String? extensionPath,
  required final String? operation,
  required final String detail,
}) implements Exception {
  @override
  String toString() => "Pi extension handler failed (path: $extensionPath, event: $operation): $detail";
}
