import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "assistant_message_mapper.dart";
import "message_part_mapper.dart";
import "models/openapi/assistant_message.g.dart";
import "models/openapi/user_message.g.dart";
import "models/sse_event_data.g.dart";
import "opencode_command_mapper.dart";
import "opencode_command_tracker.dart";
import "sse_event_mapper.dart";

/// Owns command-aware decisions for OpenCode's live event stream.
class OpenCodeCommandEventService {
  OpenCodeCommandEventService({
    required OpenCodeCommandTracker tracker,
    required OpenCodeCommandMapper commandMapper,
    required SseEventMapper eventMapper,
    required MessagePartMapper messagePartMapper,
    required AssistantMessageMapper assistantMessageMapper,
  }) : _tracker = tracker,
       _commandMapper = commandMapper,
       _eventMapper = eventMapper,
       _messagePartMapper = messagePartMapper,
       _assistantMessageMapper = assistantMessageMapper;

  final OpenCodeCommandTracker _tracker;
  final OpenCodeCommandMapper _commandMapper;
  final SseEventMapper _eventMapper;
  final MessagePartMapper _messagePartMapper;
  final AssistantMessageMapper _assistantMessageMapper;

  List<BridgeSseEvent> map(
    SseEventData event, {
    required String? displaySessionId,
  }) {
    switch (event) {
      case SseMessageUpdated(:final info):
        _tracker.observeMessage(info);
        if (info is UserMessage) return const [];
        if (info case final AssistantMessage assistant) {
          final command = _tracker.commandForResult(assistant.id);
          if (command != null) {
            if (_assistantMessageMapper.map(assistant) case final PluginMessageError error) {
              return [
                BridgeSseMessagePartUpdated(
                  part: _commandMapper.mapErrorResult(
                    error: error,
                    commandMessageId: command.triggerMessageId,
                  ),
                ),
              ];
            }
            return const [];
          }
        }
      case SseMessagePartUpdated(:final part):
        _tracker.observePart(part);
        final messageId = _messagePartMapper.mapPart(part).messageID;
        final triggerCommand = _tracker.commandForTrigger(messageId);
        if (triggerCommand != null) {
          final command = _tracker.takeCommandTrigger(messageId);
          if (command == null) return const [];
          return [
            BridgeSseMessageUpdated(
              info: _commandMapper
                  .mapCommand(
                    id: command.triggerMessageId,
                    sessionId: command.sessionId,
                    name: command.name,
                    arguments: command.arguments,
                    origin: command.origin,
                    invocationId: command.invocationId,
                    time: command.time,
                  )
                  .toJson(),
            ),
          ];
        }
        if (_tracker.isGuidanceSuppressed(messageId)) return const [];
        final resultCommand = _tracker.commandForResult(messageId);
        if (resultCommand != null) {
          return _reparent(event: event, commandMessageId: resultCommand.triggerMessageId);
        }
        final heldUser = _tracker.takeReleasedUser(messageId);
        if (heldUser != null) {
          final messageEvent = _eventMapper.map(
            SseEventData.messageUpdated(info: heldUser),
          );
          final partEvent = _eventMapper.map(event);
          return [messageEvent, partEvent].nonNulls.toList();
        }
      case SseMessagePartDelta(:final messageID, :final partID) ||
          SseMessagePartRemoved(:final messageID, :final partID):
        if (event is SseMessagePartDelta) {
          _tracker.observePartDelta(messageId: messageID, partId: partID);
        }
        if (_tracker.isGuidanceSuppressed(messageID)) return const [];
        final command = _tracker.commandForResult(messageID);
        if (command != null) {
          return _reparent(event: event, commandMessageId: command.triggerMessageId);
        }
      case SseMessageRemoved(:final sessionID, :final messageID):
        final command = _tracker.commandForResult(messageID);
        final isSuppressed = _tracker.isGuidanceSuppressed(messageID);
        final removedParts = command == null
            ? const <BridgeSseEvent>[]
            : [
                for (final partID in _tracker.partIdsForResult(
                  messageId: messageID,
                ))
                  ..._reparent(
                    event: SseEventData.messagePartRemoved(
                      sessionID: sessionID,
                      messageID: messageID,
                      partID: partID,
                    ),
                    commandMessageId: command.triggerMessageId,
                  ),
              ];
        _tracker.forgetMessage(messageID);
        if (command != null) return removedParts;
        if (isSuppressed) return const [];
      case SseSessionDeleted(:final info):
        _tracker.forgetSession(info.id);
      default:
        break;
    }
    final mapped = _eventMapper.map(event, displaySessionId: displaySessionId);
    return mapped == null ? const [] : [mapped];
  }

  List<BridgeSseEvent> _reparent({
    required SseEventData event,
    required String commandMessageId,
  }) {
    final mapped = _eventMapper.map(event);
    return mapped == null
        ? const []
        : [
            _commandMapper.reparentEvent(
              event: mapped,
              commandMessageId: commandMessageId,
            ),
          ];
  }
}
