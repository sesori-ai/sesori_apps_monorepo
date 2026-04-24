import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../../plugin_to_shared_mapping.dart";

/// Maps plugin-level message types to shared [Message] types.
extension PluginMessageMapper on PluginMessage {
  Message toSharedMessage() {
    if (error != null) {
      return Message.error(
        id: id,
        sessionID: sessionID,
        agent: agent,
        modelID: modelID,
        providerID: providerID,
        errorName: error!.name,
        errorMessage: error!.message,
      );
    }
    return switch (role) {
      "user" => Message.user(
        id: id,
        sessionID: sessionID,
        agent: agent,
      ),
      "assistant" => Message.assistant(
        id: id,
        sessionID: sessionID,
        agent: agent,
        modelID: modelID,
        providerID: providerID,
      ),
      _ => throw ArgumentError('Unknown message role: $role'),
    };
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
