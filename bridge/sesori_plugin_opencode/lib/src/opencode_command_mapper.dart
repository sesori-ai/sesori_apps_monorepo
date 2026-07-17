import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

/// Pure OpenCode command conversion shared by live SSE and history reloads.
class OpenCodeCommandMapper {
  const OpenCodeCommandMapper();

  PluginMessage mapCommand({
    required String id,
    required String sessionId,
    required String name,
    required String? arguments,
    required PluginCommandOrigin origin,
    required String? invocationId,
    required PluginMessageTime? time,
  }) {
    return PluginMessage.command(
      id: id,
      sessionID: sessionId,
      name: name,
      arguments: arguments,
      origin: origin,
      invocationId: invocationId,
      time: time,
    );
  }

  PluginMessagePart mapErrorResult({
    required PluginMessageError error,
    required String commandMessageId,
  }) {
    return PluginMessagePart(
      id: error.id,
      sessionID: error.sessionID,
      messageID: commandMessageId,
      type: PluginMessagePartType.text,
      text: error.errorMessage,
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

  PluginMessagePart reparentPart({
    required PluginMessagePart part,
    required String commandMessageId,
  }) => part.copyWith(messageID: commandMessageId);

  BridgeSseEvent reparentEvent({
    required BridgeSseEvent event,
    required String commandMessageId,
  }) {
    return switch (event) {
      BridgeSseMessagePartUpdated(:final part) => BridgeSseMessagePartUpdated(
        part: reparentPart(
          part: part,
          commandMessageId: commandMessageId,
        ),
      ),
      BridgeSseMessagePartDelta(
        :final sessionID,
        :final partID,
        :final field,
        :final delta,
      ) =>
        BridgeSseMessagePartDelta(
          sessionID: sessionID,
          messageID: commandMessageId,
          partID: partID,
          field: field,
          delta: delta,
        ),
      BridgeSseMessagePartRemoved(:final sessionID, :final partID) => BridgeSseMessagePartRemoved(
        sessionID: sessionID,
        messageID: commandMessageId,
        partID: partID,
      ),
      _ => event,
    };
  }
}
