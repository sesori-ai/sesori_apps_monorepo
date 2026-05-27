import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../api/codex_defaults_api.dart";
import "mappers/plugin_message_mapper.dart";

class MessageRepository {
  final BridgePluginApi _plugin;
  final CodexDefaultsApi _codexDefaultsApi;

  MessageRepository({
    required BridgePluginApi plugin,
    required CodexDefaultsApi codexDefaultsApi,
  }) : _plugin = plugin,
       _codexDefaultsApi = codexDefaultsApi;

  Future<List<MessageWithParts>> getMessages({required String sessionId}) async {
    final sharedMessages = (await _plugin.getSessionMessages(sessionId)).toSharedMessageWithParts();
    if (_plugin.id != "codex") {
      return sharedMessages;
    }

    final defaults = _codexDefaultsApi.readSessionDefaults(sessionId: sessionId);
    if (defaults.modelId == null || defaults.modelProvider == null) {
      return sharedMessages;
    }

    return sharedMessages
        .map((message) => _enrichCodexMessage(message: message, defaults: defaults))
        .toList(growable: false);
  }

  MessageWithParts _enrichCodexMessage({
    required MessageWithParts message,
    required CodexSelectionDefaults defaults,
  }) {
    return message.copyWith(
      info: switch (message.info) {
        MessageAssistant(:final id, :final sessionID, :final agent, :final modelID, :final providerID) =>
          Message.assistant(
            id: id,
            sessionID: sessionID,
            agent: agent ?? defaults.agent,
            modelID: modelID ?? defaults.modelId,
            providerID: providerID ?? defaults.modelProvider,
          ),
        MessageError(
          :final id,
          :final sessionID,
          :final agent,
          :final modelID,
          :final providerID,
          :final errorName,
          :final errorMessage,
        ) =>
          Message.error(
            id: id,
            sessionID: sessionID,
            agent: agent ?? defaults.agent,
            modelID: modelID ?? defaults.modelId,
            providerID: providerID ?? defaults.modelProvider,
            errorName: errorName,
            errorMessage: errorMessage,
          ),
        MessageUser() => message.info,
      },
    );
  }
}
