import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../../plugin_to_shared_mapping.dart";

/// Maps plugin-level message types to shared [Message] types.
extension PluginMessageMapper on PluginMessage {
  Message toSharedMessage() => switch (this) {
    PluginMessageUser(:final id, :final sessionID, :final agent, :final time) => Message.user(
      id: id,
      sessionID: sessionID,
      agent: agent,
      time: time.toShared(),
    ),
    PluginMessageAssistant(:final id, :final sessionID, :final agent, :final modelID, :final providerID, :final time) =>
      Message.assistant(
        id: id,
        sessionID: sessionID,
        agent: agent,
        modelID: modelID,
        providerID: providerID,
        time: time.toShared(),
      ),
    PluginMessageError(
      :final id,
      :final sessionID,
      :final agent,
      :final modelID,
      :final providerID,
      :final errorName,
      :final errorMessage,
      :final time,
    ) =>
      Message.error(
        id: id,
        sessionID: sessionID,
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
  MessageWithParts toSharedMessageWithParts() {
    return MessageWithParts(
      info: info.toSharedMessage(),
      parts: parts.map((p) => p.toShared()).toList(),
    );
  }
}

extension PluginMessagePartsMapper on Iterable<PluginMessageWithParts> {
  List<MessageWithParts> toSharedMessageWithParts() {
    return map((m) => m.toSharedMessageWithParts()).toList(growable: false);
  }
}
