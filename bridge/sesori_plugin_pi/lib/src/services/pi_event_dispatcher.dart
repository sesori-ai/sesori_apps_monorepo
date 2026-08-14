import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "../api/models/pi_assistant_delta.dart";
import "../api/models/pi_event.dart";
import "../api/models/pi_session_history_dto.dart";
import "../models/pi_assistant_stop_reason.dart";
import "../repositories/mappers/pi_history_mapper.dart";
import "../repositories/mappers/pi_message_identity_builder.dart";
import "../repositories/trackers/pi_message_identity_tracker.dart";
import "../repositories/trackers/pi_tool_tracker.dart";

final class PiEventDispatcher({
  required final PiHistoryMapper historyMapper,
  required final PiMessageIdentityTracker identityTracker,
  required final PiToolTracker toolTracker,
}) {
  final PiHistoryMapper _historyMapper = historyMapper;
  final PiMessageIdentityTracker _identityTracker = identityTracker;
  final PiToolTracker _tools = toolTracker;
  final Map<String, _SessionState> _sessions = {};

  void beginTurn({required String sessionId}) {
    _session(sessionId).clearMessage();
    _tools.beginTurn(sessionId: sessionId);
  }

  void forgetSession({required String sessionId}) {
    _sessions.remove(sessionId);
    _identityTracker.forgetSession(sessionId: sessionId);
    _tools.forgetSession(sessionId: sessionId);
  }

  List<BridgeSseEvent> map({required String sessionId, required PiEvent event, DateTime? now}) => switch (event) {
    PiAgentStartEvent() => [
      BridgeSseSessionStatus(sessionID: sessionId, status: const PluginSessionStatus.busy().toJson()),
    ],
    PiAgentSettledEvent() => [
      BridgeSseSessionStatus(sessionID: sessionId, status: const PluginSessionStatus.idle().toJson()),
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
    PiAutoRetryStartEvent(:final attempt, :final delayMs) => _retry(
      sessionId: sessionId,
      attempt: attempt,
      delayMs: delayMs,
      now: now ?? DateTime.now(),
    ),
    PiSummarizationRetryScheduledEvent(:final attempt, :final delayMs) => _retry(
      sessionId: sessionId,
      attempt: attempt,
      delayMs: delayMs,
      now: now ?? DateTime.now(),
    ),
    PiAutoRetryEndEvent(:final success) when !success => [BridgeSseSessionError(sessionID: sessionId)],
    PiCompactionStartEvent() => [
      BridgeSseSessionStatus(sessionID: sessionId, status: const PluginSessionStatus.busy().toJson()),
    ],
    PiCompactionEndEvent(:final aborted, :final errorMessage) => _compactionEnd(
      sessionId: sessionId,
      failed: aborted || errorMessage != null,
    ),
    PiExtensionErrorEvent(:final error) => _extensionError(error: error),
    PiAgentEndEvent() ||
    PiTurnStartEvent() ||
    PiTurnEndEvent() ||
    PiBashExecutionUpdateEvent() ||
    PiQueueUpdateEvent() ||
    PiEntryAppendedEvent() ||
    PiSessionInfoChangedEvent() ||
    PiThinkingLevelChangedEvent() ||
    PiAutoRetryEndEvent() ||
    PiSummarizationRetryAttemptStartEvent() ||
    PiSummarizationRetryFinishedEvent() ||
    PiUnknownEvent() => const [],
  };

  List<BridgeSseEvent> _messageStart({required String sessionId, required Map<String, Object?> raw}) {
    final message = _historyMapper.decodeAssistantMessage(raw: raw);
    if (message == null) return const [];
    final state = _session(sessionId);
    state
      ..messageId = state.identities.next(role: PiMessageIdentityRole.assistant, timestamp: message.timestamp)
      ..message = message
      ..announced = false
      ..startedParts.clear();
    return const [];
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
    if (message == null) return const [];
    final state = _session(sessionId);
    final messageId =
        state.messageId ?? state.identities.next(role: PiMessageIdentityRole.assistant, timestamp: message.timestamp);
    final mapped = _historyMapper.mapAssistantMessage(sessionId: sessionId, messageId: messageId, message: message);
    final parts = <PluginMessagePart>[];
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
      parts.add(_toolPart(sessionId: sessionId, tool: terminal ?? tracked));
    }
    final removedPartIds = state.emittedPartIds.difference({for (final part in parts) part.id});
    state.clearMessage();
    return [
      BridgeSseMessageUpdated(info: mapped.info.toJson()),
      for (final part in parts) BridgeSseMessagePartUpdated(part: part),
      for (final partId in removedPartIds)
        BridgeSseMessagePartRemoved(sessionID: sessionId, messageID: messageId, partID: partId),
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

  List<BridgeSseEvent> _retry({
    required String sessionId,
    required int? attempt,
    required int? delayMs,
    required DateTime now,
  }) {
    if (attempt == null || delayMs == null || attempt < 0 || delayMs < 0) return const [];
    return [
      BridgeSseSessionStatus(
        sessionID: sessionId,
        status: PluginSessionStatus.retry(
          attempt: attempt,
          message: "Pi is retrying the provider request.",
          next: now.millisecondsSinceEpoch + delayMs,
        ).toJson(),
      ),
    ];
  }

  List<BridgeSseEvent> _compactionEnd({required String sessionId, required bool failed}) {
    if (failed) return [BridgeSseSessionError(sessionID: sessionId)];
    final state = _session(sessionId);
    final messageId = state.identities.nextCompaction();
    final mapped = _historyMapper.mapCompaction(sessionId: sessionId, messageId: messageId);
    return [
      BridgeSseSessionCompacted(sessionID: sessionId),
      BridgeSseMessageUpdated(info: mapped.info.toJson()),
      for (final part in mapped.parts) BridgeSseMessagePartUpdated(part: part),
    ];
  }

  List<BridgeSseEvent> _extensionError({required String? error}) {
    if (error != null) Log.w("[pi] extension handler failed", _PiExtensionFailureDiagnostic(detail: error));
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

final class _SessionState({required final PiMessageIdentityBuilder identities}) {
  String? messageId;
  PiAssistantMessageDto? message;
  bool announced = false;
  final Set<({int contentIndex, PluginMessagePartType type})> startedParts = {};
  final Set<String> emittedPartIds = {};

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
}) => PluginMessagePart(
  id: _blockId(messageId: messageId, contentIndex: contentIndex),
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

PluginMessagePart _toolPart({required String sessionId, required PiTrackedTool tool}) => PluginMessagePart(
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

String _blockId({required String messageId, required int contentIndex}) => "$messageId-block-${contentIndex + 1}";

final class const _PiExtensionFailureDiagnostic({required final String detail}) implements Exception {
  @override
  String toString() => "Pi extension handler failed: $detail";
}
