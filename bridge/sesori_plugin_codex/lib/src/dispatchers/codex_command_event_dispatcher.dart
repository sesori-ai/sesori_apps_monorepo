import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "../repositories/models/codex_app_server_repository_models.dart";
import "../trackers/codex_command_invocation_tracker.dart";

/// Converts one accepted Codex slash turn into one live command timeline row.
class CodexCommandEventDispatcher {
  CodexCommandEventDispatcher({
    required CodexCommandInvocationTracker tracker,
  }) : _tracker = tracker;

  final CodexCommandInvocationTracker _tracker;

  List<BridgeSseEvent> eventsForReturnedInvocation({
    required CodexCommandInvocationSnapshot? invocation,
  }) {
    return invocation == null ? const [] : _commandEvent(invocation);
  }

  List<BridgeSseEvent> handleEvent({
    required CodexEventRecord event,
    required List<BridgeSseEvent> ordinaryEvents,
  }) {
    final threadId = event.threadId;
    final turnId = event.turnId;

    if (event is CodexTurnStartedEventRecord && threadId != null && turnId != null) {
      final invocation = _tracker.activeFor(threadId: threadId, turnId: turnId);
      return [
        if (invocation != null) ..._commandEvent(invocation),
        ...ordinaryEvents,
      ];
    }

    if (threadId == null) return ordinaryEvents;
    final invocation = _tracker.activeFor(threadId: threadId, turnId: turnId);
    if (invocation == null) return ordinaryEvents;
    final activeTurnId = invocation.turnId;
    if (activeTurnId == null) return ordinaryEvents;

    switch (event) {
      case CodexItemEventRecord(:final item):
        if (item == null) return ordinaryEvents;
        final itemId = item.id;
        if (item is CodexUserMessageItemRecord) {
          final text = item.text;
          final isEcho = invocation.userMessageId == itemId || text == invocation.expectedUserText;
          if (!isEcho) return ordinaryEvents;
          _tracker.recordUserMessage(turnId: activeTurnId, messageId: itemId);
          return const [];
        }
        if (item is CodexAgentMessageItemRecord) {
          _tracker.recordResult(turnId: activeTurnId, messageId: itemId);
          final text = item.text;
          final updated = text == null
              ? _tracker.activeFor(threadId: threadId, turnId: activeTurnId)
              : _tracker.replaceResultText(
                  turnId: activeTurnId,
                  messageId: itemId,
                  text: text,
                );
          return updated == null
              ? const []
              : [
                  BridgeSseMessagePartUpdated(
                    part: _resultPart(updated, text: updated.resultText ?? ""),
                  ),
                ];
        }
        if (item is CodexReasoningItemRecord || item is CodexToolItemRecord) {
          _tracker.recordResult(turnId: activeTurnId, messageId: itemId);
          return _reparentAssistantEvents(
            events: ordinaryEvents,
            turnId: activeTurnId,
            commandMessageId: invocation.commandMessageId,
          );
        }
        return ordinaryEvents;

      case CodexAgentMessageDeltaEventRecord(:final itemId, :final delta):
        if (itemId == null || delta == null) return ordinaryEvents;
        final updated = _tracker.appendResultText(
          turnId: activeTurnId,
          messageId: itemId,
          delta: delta,
        );
        if (updated == null) return const [];
        return [
          BridgeSseMessagePartDelta(
            sessionID: threadId,
            messageID: updated.commandMessageId,
            partID: _resultPartId(updated),
            field: "text",
            delta: delta,
          ),
        ];

      case CodexReasoningDeltaEventRecord(:final itemId):
        if (itemId == null) return ordinaryEvents;
        _tracker.recordResultPart(
          turnId: activeTurnId,
          messageId: itemId,
          partId: "$itemId-reasoning",
        );
        return _reparentAssistantEvents(
          events: ordinaryEvents,
          turnId: activeTurnId,
          commandMessageId: invocation.commandMessageId,
        );

      case CodexCommandExecutionOutputDeltaEventRecord():
        return _reparentAssistantEvents(
          events: ordinaryEvents,
          turnId: activeTurnId,
          commandMessageId: invocation.commandMessageId,
        );

      case CodexItemRemovedEventRecord(:final itemId):
        if (itemId == null) return ordinaryEvents;
        final removed = _tracker.removeResult(turnId: activeTurnId, messageId: itemId);
        if (removed == null) return ordinaryEvents;
        final events = <BridgeSseEvent>[
          for (final partId in removed.partIds)
            BridgeSseMessagePartRemoved(
              sessionID: threadId,
              messageID: removed.invocation.commandMessageId,
              partID: partId,
            ),
        ];
        if (removed.hadDisplayText) {
          final text = removed.invocation.resultText;
          events.add(
            text == null
                ? BridgeSseMessagePartRemoved(
                    sessionID: threadId,
                    messageID: removed.invocation.commandMessageId,
                    partID: _resultPartId(removed.invocation),
                  )
                : BridgeSseMessagePartUpdated(
                    part: _resultPart(removed.invocation, text: text),
                  ),
          );
        }
        return events;

      case CodexItemPartRemovedEventRecord(:final itemId, :final partId):
        if (itemId != null && partId != null) {
          _tracker.removeResultPart(
            turnId: activeTurnId,
            messageId: itemId,
            partId: partId,
          );
        }
        return _reparentAssistantEvents(
          events: ordinaryEvents,
          turnId: activeTurnId,
          commandMessageId: invocation.commandMessageId,
        );

      case CodexTurnCompletedEventRecord():
      case CodexErrorEventRecord():
        _tracker.complete(threadId: threadId, turnId: turnId);
        return ordinaryEvents;
      case CodexThreadStartedEventRecord():
      case CodexThreadNameUpdatedEventRecord():
      case CodexThreadStatusChangedEventRecord():
      case CodexThreadClosedEventRecord():
      case CodexTurnStartedEventRecord():
      case CodexTurnDiffUpdatedEventRecord():
      case CodexProjectChangedEventRecord():
      case CodexIgnoredEventRecord():
        return ordinaryEvents;
    }
  }

  List<BridgeSseEvent> _commandEvent(CodexCommandInvocationSnapshot invocation) {
    final turnId = invocation.turnId;
    if (turnId == null || invocation.commandEmitted) return const [];
    final emitted = _tracker.markCommandEmitted(turnId: turnId);
    return [
      BridgeSseMessageUpdated(
        info: PluginMessage.command(
          id: emitted.commandMessageId,
          sessionID: emitted.threadId,
          name: emitted.command,
          arguments: emitted.arguments,
          origin: PluginCommandOrigin.manual,
          invocationId: emitted.invocationId,
          time: null,
        ).toJson(),
      ),
    ];
  }

  List<BridgeSseEvent> _reparentAssistantEvents({
    required List<BridgeSseEvent> events,
    required String turnId,
    required String commandMessageId,
  }) {
    final out = <BridgeSseEvent>[];
    for (final event in events) {
      switch (event) {
        case BridgeSseMessageUpdated():
          continue;
        case BridgeSseMessagePartUpdated(:final part):
          _tracker.recordResultPart(
            turnId: turnId,
            messageId: part.messageID,
            partId: part.id,
          );
          out.add(
            BridgeSseMessagePartUpdated(
              part: part.copyWith(messageID: commandMessageId),
            ),
          );
        case BridgeSseMessagePartDelta(
          :final sessionID,
          :final messageID,
          :final partID,
          :final field,
          :final delta,
        ):
          _tracker.recordResultPart(
            turnId: turnId,
            messageId: messageID,
            partId: partID,
          );
          out.add(
            BridgeSseMessagePartDelta(
              sessionID: sessionID,
              messageID: commandMessageId,
              partID: partID,
              field: field,
              delta: delta,
            ),
          );
        case BridgeSseMessagePartRemoved(:final sessionID, :final partID):
          out.add(
            BridgeSseMessagePartRemoved(
              sessionID: sessionID,
              messageID: commandMessageId,
              partID: partID,
            ),
          );
        case BridgeSseMessageRemoved():
          continue;
        default:
          out.add(event);
      }
    }
    return out;
  }

  PluginMessagePart _resultPart(
    CodexCommandInvocationSnapshot invocation, {
    required String text,
  }) => PluginMessagePart(
    id: _resultPartId(invocation),
    sessionID: invocation.threadId,
    messageID: invocation.commandMessageId,
    type: PluginMessagePartType.text,
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

  static String _resultPartId(CodexCommandInvocationSnapshot invocation) => "${invocation.commandMessageId}-result";
}
