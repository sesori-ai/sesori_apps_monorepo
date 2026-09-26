import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart" as shared;

import "../models/openapi/permission_request.g.dart";
import "../models/openapi/session_message_agent_selected.g.dart";
import "../models/openapi/session_message_info.g.dart";
import "../models/openapi/session_message_synthetic.g.dart";
import "../models/v2_agent_names.dart";
import "../models/v2_event.g.dart";
import "../models/v2_execution_interrupt_reason.dart";
import "../repositories/v2_message_mapper.dart";
import "../repositories/v2_model_mapper.dart";

/// Pure live-event projection. Missing native context is supplied by the service
/// from REST; this mapper never accumulates transcript or tool state.
class const V2EventMapper({required final V2ModelMapper _modelMapper, required final V2MessageMapper _messageMapper}) {
  /// Shared with activity tracking so shutdown never becomes a false idle edge.
  static ({String sessionId, PluginSessionStatus status})? status({required V2EventData event}) => switch (event) {
    V2SessionExecutionStarted(:final sessionID) ||
    V2SessionStepStarted(:final sessionID) => (sessionId: sessionID, status: const PluginSessionStatus.busy()),
    V2SessionRetryScheduled() => (
      sessionId: event.sessionID,
      status: PluginSessionStatus.retry(
        attempt: event.attempt,
        message: event.error.message,
        next: event.at,
      ),
    ),
    V2SessionExecutionSucceeded(:final sessionID) ||
    V2SessionExecutionFailed(:final sessionID) ||
    V2SessionExecutionInterrupted(
      :final sessionID,
      reason: V2ExecutionInterruptReason.user ||
          V2ExecutionInterruptReason.superseded ||
          V2ExecutionInterruptReason.inactivity,
    ) => (sessionId: sessionID, status: const PluginSessionStatus.idle()),
    _ => null,
  };

  List<BridgeSseEvent> map({required V2EventEnvelope envelope}) {
    final event = envelope.data;
    return [
      if (status(event: event) case final projected?)
        BridgeSseSessionStatus(sessionID: projected.sessionId, status: projected.status),
      ...switch (event) {
        V2ServerConnected() => [const BridgeSseServerConnected()],
        V2ProjectUpdated() => [const BridgeSseProjectUpdated()],
        V2SessionExecutionFailed() => [
          BridgeSseSessionError(sessionID: event.sessionID),
          BridgeSseTuiToastShow(
            sessionID: event.sessionID,
            title: "OpenCode turn failed",
            message: event.error.message,
            variant: "error",
          ),
        ],
        V2SessionTextStarted() => [
          _text(
            sessionId: event.sessionID,
            messageId: event.assistantMessageID,
            ordinal: event.ordinal,
            text: "",
            kind: _TextKind.text,
          ),
        ],
        V2SessionTextEnded() => [
          _text(
            sessionId: event.sessionID,
            messageId: event.assistantMessageID,
            ordinal: event.ordinal,
            text: event.text,
            kind: _TextKind.text,
          ),
        ],
        V2SessionReasoningStarted() => [
          _text(
            sessionId: event.sessionID,
            messageId: event.assistantMessageID,
            ordinal: event.ordinal,
            text: "",
            kind: _TextKind.reasoning,
          ),
        ],
        V2SessionReasoningEnded() => [
          _text(
            sessionId: event.sessionID,
            messageId: event.assistantMessageID,
            ordinal: event.ordinal,
            text: event.text,
            kind: _TextKind.reasoning,
          ),
        ],
        V2SessionTextDelta(:final sessionID, :final assistantMessageID, :final ordinal, :final delta) ||
        V2SessionReasoningDelta(:final sessionID, :final assistantMessageID, :final ordinal, :final delta) => [
          BridgeSseMessagePartDelta(
            sessionID: sessionID,
            messageID: assistantMessageID,
            partID: V2MessageMapper.partId(messageId: assistantMessageID, ordinal: ordinal),
            field: "text",
            delta: delta,
          ),
        ],
        V2SessionToolInputStarted() => [
          BridgeSseMessagePartUpdated(
            part: PluginMessagePart.tool(
              id: event.id,
              sessionID: event.sessionID,
              messageID: event.assistantMessageID,
              tool: event.name,
              state: const PluginToolState(
                status: PluginToolStatus.pending,
                title: null,
                shellCommand: null,
                output: null,
                error: null,
                attachments: [],
              ),
            ),
          ),
        ],
        V2SessionRetryScheduled() => [
          BridgeSseMessagePartUpdated(
            part: PluginMessagePart.retry(
              id: V2MessageMapper.retryPartId(messageId: event.assistantMessageID),
              sessionID: event.sessionID,
              messageID: event.assistantMessageID,
              attempt: event.attempt,
              retryError: event.error.message,
            ),
          ),
        ],
        // Enqueue is not delivery. Partial tool input is not valid JSON, and
        // snapshot-dependent events are handled by the enriched methods below.
        _ => const <BridgeSseEvent>[],
      },
    ];
  }

  BridgeSseEvent? mapSession({required V2EventData event, required shared.Session session}) => switch (event) {
    V2SessionCreated() => BridgeSseSessionCreated(info: session.toJson()),
    V2SessionRenamed() => BridgeSseSessionUpdated(info: session.toJson(), titleChanged: true),
    V2SessionDeleted() => BridgeSseSessionDeleted(info: session.toJson()),
    _ => null,
  };

  List<BridgeSseEvent> mapAssistantStarted({required V2SessionStepStarted event, required V2AgentNames agentNames}) => [
    BridgeSseMessageUpdated(
      info: PluginMessage.assistant(
        id: event.assistantMessageID,
        sessionID: event.sessionID,
        agent: agentNames.displayName(id: event.agent),
        modelID: event.model.id,
        providerID: event.model.providerID,
        variant: event.model.variant,
        sender: PluginMessageSender.agent,
        time: PluginMessageTime(created: event.started, completed: null),
      ),
    ),
    _removeRetry(sessionId: event.sessionID, messageId: event.assistantMessageID),
  ];

  /// Terminal snapshots must not replay unrelated text ahead of queued deltas.
  List<BridgeSseEvent> mapAssistantSnapshot({required PluginMessageWithParts message}) => [
    BridgeSseMessageUpdated(info: message.info),
    if (message.parts.whereType<PluginMessagePartRetry>().firstOrNull case final retry?)
      BridgeSseMessagePartUpdated(part: retry)
    else
      _removeRetry(sessionId: message.info.sessionID, messageId: message.info.id),
  ];

  List<BridgeSseEvent> mapToolSnapshot({required String toolId, required PluginMessageWithParts message}) => [
    for (final part in message.parts.whereType<PluginMessagePartTool>())
      if (part.id == toolId) BridgeSseMessagePartUpdated(part: part),
  ];

  /// For complete delivered user/synthetic messages and compaction snapshots.
  List<BridgeSseEvent> mapMessageSnapshot({required PluginMessageWithParts message}) => [
    BridgeSseMessageUpdated(info: message.info),
    for (final part in message.parts) BridgeSseMessagePartUpdated(part: part),
    if (message.parts.any((part) => part is PluginMessagePartCompaction))
      BridgeSseSessionCompacted(sessionID: message.info.sessionID),
  ];

  List<BridgeSseEvent> mapNotice({required V2EventEnvelope envelope, required V2AgentNames agentNames}) {
    // Same conversion as native Session.Message.ID.fromEvent; inbox IDs already
    // are message IDs and do not use this conversion.
    final messageId = envelope.id.replaceFirst(RegExp("^evt_"), "msg_");
    final ({String sessionId, SessionMessageInfo message})? notice = switch (envelope.data) {
      V2SessionAgentSelected(:final sessionID, :final agent, :final previous) => (
        sessionId: sessionID,
        message: SessionMessageAgentSelected(
          id: messageId,
          metadata: null,
          agent: agent,
          previous: previous,
          time: SessionMessageAgentSelectedTime(created: envelope.created),
        ),
      ),
      V2SessionSynthetic(:final sessionID, :final text, :final description) => (
        sessionId: sessionID,
        message: SessionMessageSynthetic(
          id: messageId,
          metadata: null,
          text: text,
          description: description,
          time: SessionMessageSyntheticTime(created: envelope.created),
        ),
      ),
      _ => null,
    };
    if (notice == null) return const [];
    return mapMessageSnapshot(
      message: _messageMapper.mapMessage(
        sessionId: notice.sessionId,
        message: notice.message,
        agentNames: agentNames,
      )!,
    );
  }

  List<BridgeSseEvent> mapInput({required V2EventData event, required String? displaySessionId}) {
    switch (event) {
      case V2PermissionAsked():
        final permission = _modelMapper.mapPermission(
          permission: PermissionRequest(
            id: event.id,
            sessionID: event.sessionID,
            action: event.action,
            resources: event.resources,
            save: event.save,
            metadata: event.metadata,
            source: event.source,
            message: event.message,
          ),
          displaySessionId: displaySessionId,
        );
        return [
          BridgeSsePermissionAsked(
            requestID: permission.id,
            sessionID: permission.sessionID,
            displaySessionId: displaySessionId,
            tool: permission.tool,
            description: permission.description,
            allowAlways: permission.allowAlways,
          ),
        ];
      case V2PermissionReplied():
        return [
          BridgeSsePermissionReplied(
            requestID: event.requestID,
            sessionID: event.sessionID,
            displaySessionId: displaySessionId,
            reply: event.reply.toJson(),
          ),
        ];
      case V2FormCreated():
        final form = _modelMapper.mapForm(form: event.form, displaySessionId: displaySessionId);
        return [
          if (form != null)
            BridgeSseQuestionAsked(
              id: form.id,
              sessionID: form.sessionID,
              displaySessionId: displaySessionId,
              questions: form.questions,
            ),
        ];
      case V2FormReplied():
        return [
          BridgeSseQuestionReplied(requestID: event.id, sessionID: event.sessionID, displaySessionId: displaySessionId),
        ];
      case V2FormCancelled():
        return [
          BridgeSseQuestionRejected(
            requestID: event.id,
            sessionID: event.sessionID,
            displaySessionId: displaySessionId,
          ),
        ];
      default:
        return const [];
    }
  }

  BridgeSseMessagePartUpdated _text({
    required String sessionId,
    required String messageId,
    required int ordinal,
    required String text,
    required _TextKind kind,
  }) {
    final id = V2MessageMapper.partId(messageId: messageId, ordinal: ordinal);
    return BridgeSseMessagePartUpdated(
      part: switch (kind) {
        _TextKind.text => PluginMessagePart.text(id: id, sessionID: sessionId, messageID: messageId, text: text),
        _TextKind.reasoning => PluginMessagePart.reasoning(
          id: id,
          sessionID: sessionId,
          messageID: messageId,
          text: text,
        ),
      },
    );
  }

  BridgeSseMessagePartRemoved _removeRetry({required String sessionId, required String messageId}) =>
      BridgeSseMessagePartRemoved(
        sessionID: sessionId,
        messageID: messageId,
        partID: V2MessageMapper.retryPartId(messageId: messageId),
      );
}

enum _TextKind() {
  text,
  reasoning,
}
