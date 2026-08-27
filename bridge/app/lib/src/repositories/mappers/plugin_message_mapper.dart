import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";

import "plugin_to_shared_mapping.dart";

/// Maps plugin-level message types to shared [Message] types.
extension PluginMessageMapper on PluginMessage {
  Message toSharedMessage({required String sessionId}) => switch (this) {
    PluginMessageUser(:final id, :final agent, :final time, :final promptId) => Message.user(
      id: id,
      sessionID: sessionId,
      agent: agent,
      time: time.toShared(),
      promptId: promptId,
    ),
    PluginMessageAssistant(:final id, :final agent, :final modelID, :final providerID, :final time) =>
      Message.assistant(
        id: id,
        sessionID: sessionId,
        agent: agent,
        modelID: modelID,
        providerID: providerID,
        time: time.toShared(),
      ),
    PluginMessageError(
      :final id,
      :final agent,
      :final modelID,
      :final providerID,
      :final errorName,
      :final errorMessage,
      :final time,
    ) =>
      Message.error(
        id: id,
        sessionID: sessionId,
        agent: agent,
        modelID: modelID,
        providerID: providerID,
        errorName: errorName,
        errorMessage: errorMessage,
        time: time.toShared(),
      ),
  };
}

extension on PluginMessageTime? {
  MessageTime? toShared() {
    final time = this;
    return time == null ? null : MessageTime(created: time.created, completed: time.completed);
  }
}

extension PluginMessageWithPartsMapper on PluginMessageWithParts {
  MessageWithParts toSharedMessageWithParts({required String sessionId}) {
    return MessageWithParts(
      info: info.toSharedMessage(sessionId: sessionId),
      parts: parts.map((part) => part.toShared(sessionId: sessionId)).toList(),
    );
  }
}

extension PluginMessagePartsMapper on Iterable<PluginMessageWithParts> {
  List<MessageWithParts> toSharedMessageWithParts({required String sessionId}) {
    return map((message) => message.toSharedMessageWithParts(sessionId: sessionId)).toList(growable: false);
  }
}

extension PluginMessagePromptDefaultsMapper on List<PluginMessageWithParts> {
  SessionPromptDefaults? latestPromptDefaults() {
    for (var index = length - 1; index >= 0; index--) {
      final ({String? agent, String? modelID, String? providerID, String? variant})? selection =
          switch (this[index].info) {
            PluginMessageAssistant(:final agent, :final modelID, :final providerID, :final variant) ||
            PluginMessageError(:final agent, :final modelID, :final providerID, :final variant) => (
              agent: agent,
              modelID: modelID,
              providerID: providerID,
              variant: variant,
            ),
            PluginMessageUser() => null,
          };
      if (selection == null) continue;
      final (:agent, :modelID, :providerID, :variant) = selection;
      return SessionPromptDefaults(
        agent: agent,
        model: modelID == null || providerID == null
            ? null
            : AgentModel(providerID: providerID, modelID: modelID, variant: variant),
      );
    }
    return null;
  }
}
