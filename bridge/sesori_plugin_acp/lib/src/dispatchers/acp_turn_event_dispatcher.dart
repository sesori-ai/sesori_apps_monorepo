import "dart:async";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "../acp_command_tracker.dart";
import "../acp_event_mapper.dart";
import "../repositories/models/acp_notification_record.dart";
import "../trackers/acp_command_turn_tracker.dart";
import "../trackers/acp_session_residency_tracker.dart";

class AcpTurnEventDispatcher {
  AcpTurnEventDispatcher({
    required AcpEventMapper eventMapper,
    required AcpCommandTracker commandTracker,
    required AcpCommandTurnTracker commandTurnTracker,
    required AcpSessionResidencyTracker residencyTracker,
  }) : _eventMapper = eventMapper,
       _commandTracker = commandTracker,
       _commandTurnTracker = commandTurnTracker,
       _residencyTracker = residencyTracker;

  final AcpEventMapper _eventMapper;
  final AcpCommandTracker _commandTracker;
  final AcpCommandTurnTracker _commandTurnTracker;
  final AcpSessionResidencyTracker _residencyTracker;
  final StreamController<BridgeSseEvent> _events = StreamController<BridgeSseEvent>.broadcast();
  bool _disposed = false;

  Stream<BridgeSseEvent> get events => _events.stream;

  void beginTurn({required String sessionId}) {
    _eventMapper.beginTurn(sessionId);
  }

  void recordDiscoveredSession({
    required String sessionId,
    required String projectId,
    required String? title,
    required int? updatedMs,
  }) {
    _eventMapper.setSessionProject(sessionId, projectId);
    _eventMapper.setSessionSnapshot(
      sessionId: sessionId,
      title: title,
      createdMs: updatedMs,
      updatedMs: updatedMs,
    );
  }

  void consume(AcpNotificationRecord notification) {
    if (_disposed) return;
    _commandTracker.consume(notification);
    final sessionId = notification.sessionId;
    if (notification is AcpSessionNotificationRecord &&
        notification is! AcpAvailableCommandsChangedRecord &&
        _residencyTracker.isSuppressed(sessionId!)) {
      _residencyTracker.recordSuppressedReplay(sessionId);
      return;
    }
    for (final event in _eventMapper.map(notification)) {
      final decision = _mapCommandEvent(event);
      final turnId = decision.turnId;
      if (turnId != null && !_commandTurnTracker.isAccepted(turnId)) {
        _commandTurnTracker.stage(turnId: turnId, events: decision.events);
      } else {
        decision.events.forEach(emit);
      }
    }
  }

  void stageCommandEnvelope({required String turnId}) {
    final active = _commandTurnTracker.activate(turnId);
    _commandTurnTracker.stage(
      turnId: turnId,
      events: [_commandEnvelope(active)],
    );
  }

  void flushCommand(String turnId) {
    _commandTurnTracker.accept(turnId).forEach(emit);
  }

  void abortPendingCommand({required String turnId}) {
    final invocation = _commandTurnTracker.byTurnId(turnId)!;
    emit(_commandEnvelope(invocation));
    emit(
      BridgeSseMessageRemoved(
        sessionID: invocation.sessionId,
        messageID: invocation.commandMessageId,
      ),
    );
    _commandTurnTracker.complete(turnId);
  }

  void emit(BridgeSseEvent event) {
    if (!_disposed && !_events.isClosed) _events.add(event);
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _events.close();
  }

  BridgeSseMessageUpdated _commandEnvelope(
    AcpCommandInvocationSnapshot invocation,
  ) {
    return BridgeSseMessageUpdated(
      info: PluginMessage.command(
        id: invocation.commandMessageId,
        sessionID: invocation.sessionId,
        name: invocation.name,
        arguments: invocation.arguments,
        origin: PluginCommandOrigin.manual,
        invocationId: invocation.invocationId,
        time: null,
      ).toJson(),
    );
  }

  _AcpCommandEventDecision _mapCommandEvent(BridgeSseEvent event) {
    final sessionId = _sessionId(event);
    final invocation = sessionId == null ? null : _commandTurnTracker.activeForSession(sessionId);
    if (invocation == null) {
      return _AcpCommandEventDecision(turnId: null, events: [event]);
    }
    final turnId = invocation.turnId;

    return switch (event) {
      BridgeSseMessageUpdated(:final info) => _mapEnvelope(
        turnId: turnId,
        invocation: invocation,
        event: event,
        info: info,
      ),
      BridgeSseMessageRemoved(:final messageID) =>
        invocation.assistantMessageIds.contains(messageID)
            ? _AcpCommandEventDecision(turnId: turnId, events: const [])
            : _AcpCommandEventDecision(turnId: null, events: [event]),
      BridgeSseMessagePartUpdated(:final part) => _mapPart(
        turnId: turnId,
        invocation: invocation,
        event: event,
        part: part,
      ),
      BridgeSseMessagePartDelta(
        :final messageID,
        :final partID,
        :final field,
        :final delta,
      ) =>
        _mapDelta(
          turnId: turnId,
          invocation: invocation,
          event: event,
          messageId: messageID,
          partId: partID,
          field: field,
          delta: delta,
        ),
      BridgeSseMessagePartRemoved(:final messageID, :final partID) => _mapRemoval(
        turnId: turnId,
        invocation: invocation,
        event: event,
        messageId: messageID,
        partId: partID,
      ),
      _ => _AcpCommandEventDecision(turnId: null, events: [event]),
    };
  }

  _AcpCommandEventDecision _mapEnvelope({
    required String turnId,
    required AcpCommandInvocationSnapshot invocation,
    required BridgeSseMessageUpdated event,
    required Map<String, dynamic> info,
  }) {
    if (info["role"] != "assistant") {
      return _AcpCommandEventDecision(turnId: null, events: [event]);
    }
    final messageId = info["id"];
    if (messageId is! String || messageId.isEmpty) {
      return _AcpCommandEventDecision(turnId: null, events: [event]);
    }
    _commandTurnTracker.recordAssistantMessage(
      turnId: turnId,
      messageId: messageId,
    );
    return _AcpCommandEventDecision(turnId: turnId, events: const []);
  }

  _AcpCommandEventDecision _mapPart({
    required String turnId,
    required AcpCommandInvocationSnapshot invocation,
    required BridgeSseMessagePartUpdated event,
    required PluginMessagePart part,
  }) {
    if (!invocation.assistantMessageIds.contains(part.messageID)) {
      return _AcpCommandEventDecision(turnId: null, events: [event]);
    }
    final before = _commandTurnTracker.byTurnId(turnId)!;
    _commandTurnTracker.recordAssistantPart(
      turnId: turnId,
      partId: part.id,
      type: part.type,
    );
    if (part.type != PluginMessagePartType.text) {
      return _AcpCommandEventDecision(
        turnId: turnId,
        events: [
          BridgeSseMessagePartUpdated(
            part: part.copyWith(messageID: invocation.commandMessageId),
          ),
        ],
      );
    }

    final text = part.text ?? "";
    _commandTurnTracker.markResultPartCreated(turnId: turnId);
    if (before.resultPartCreated) {
      return _AcpCommandEventDecision(
        turnId: turnId,
        events: [
          if (text.isNotEmpty)
            BridgeSseMessagePartDelta(
              sessionID: invocation.sessionId,
              messageID: invocation.commandMessageId,
              partID: invocation.resultPartId,
              field: "text",
              delta: text,
            ),
        ],
      );
    }
    return _AcpCommandEventDecision(
      turnId: turnId,
      events: [
        BridgeSseMessagePartUpdated(
          part: part.copyWith(
            id: invocation.resultPartId,
            messageID: invocation.commandMessageId,
            text: text,
          ),
        ),
      ],
    );
  }

  _AcpCommandEventDecision _mapDelta({
    required String turnId,
    required AcpCommandInvocationSnapshot invocation,
    required BridgeSseMessagePartDelta event,
    required String messageId,
    required String partId,
    required String field,
    required String delta,
  }) {
    if (!invocation.assistantMessageIds.contains(messageId)) {
      return _AcpCommandEventDecision(turnId: null, events: [event]);
    }
    final type = _commandTurnTracker.byTurnId(turnId)!.assistantPartTypes[partId];
    if (type == PluginMessagePartType.text) {
      _commandTurnTracker.markResultPartCreated(turnId: turnId);
      return _AcpCommandEventDecision(
        turnId: turnId,
        events: [
          BridgeSseMessagePartDelta(
            sessionID: invocation.sessionId,
            messageID: invocation.commandMessageId,
            partID: invocation.resultPartId,
            field: field,
            delta: delta,
          ),
        ],
      );
    }
    return _AcpCommandEventDecision(
      turnId: turnId,
      events: [
        BridgeSseMessagePartDelta(
          sessionID: invocation.sessionId,
          messageID: invocation.commandMessageId,
          partID: partId,
          field: field,
          delta: delta,
        ),
      ],
    );
  }

  _AcpCommandEventDecision _mapRemoval({
    required String turnId,
    required AcpCommandInvocationSnapshot invocation,
    required BridgeSseMessagePartRemoved event,
    required String messageId,
    required String partId,
  }) {
    if (!invocation.assistantMessageIds.contains(messageId)) {
      return _AcpCommandEventDecision(turnId: null, events: [event]);
    }
    final type = _commandTurnTracker.byTurnId(turnId)!.assistantPartTypes[partId];
    if (type == PluginMessagePartType.text) {
      _commandTurnTracker.clearResult(turnId: turnId);
    }
    return _AcpCommandEventDecision(
      turnId: turnId,
      events: [
        BridgeSseMessagePartRemoved(
          sessionID: invocation.sessionId,
          messageID: invocation.commandMessageId,
          partID: type == PluginMessagePartType.text ? invocation.resultPartId : partId,
        ),
      ],
    );
  }

  String? _sessionId(BridgeSseEvent event) => switch (event) {
    BridgeSseMessageUpdated(:final info) => info["sessionID"] as String?,
    BridgeSseMessageRemoved(:final sessionID) ||
    BridgeSseMessagePartDelta(:final sessionID) ||
    BridgeSseMessagePartRemoved(:final sessionID) => sessionID,
    BridgeSseMessagePartUpdated(:final part) => part.sessionID,
    _ => null,
  };
}

class _AcpCommandEventDecision {
  const _AcpCommandEventDecision({
    required this.turnId,
    required this.events,
  });

  final String? turnId;
  final List<BridgeSseEvent> events;
}
