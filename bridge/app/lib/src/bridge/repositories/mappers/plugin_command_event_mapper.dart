import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart" show CommandOrigin, MessagePart, MessageTime;

import "../models/command_timeline.dart";

class PluginCommandEventMapper {
  const PluginCommandEventMapper();

  CommandMessageTimelineCandidate map({
    required PluginMessageCommand command,
    required String pluginId,
    required String sessionId,
  }) {
    return mapValues(
      pluginId: pluginId,
      sessionId: sessionId,
      backendMessageId: command.id,
      invocationId: command.invocationId,
      name: command.name,
      arguments: command.arguments,
      origin: switch (command.origin) {
        PluginCommandOrigin.manual => CommandOrigin.manual,
        PluginCommandOrigin.automatic => CommandOrigin.automatic,
        PluginCommandOrigin.unknown => CommandOrigin.unknown,
      },
      time: switch (command.time) {
        PluginMessageTime(:final created, :final completed) => MessageTime(
          created: created,
          completed: completed,
        ),
        null => null,
      },
      resultParts: const [],
    );
  }

  CommandMessageTimelineCandidate mapValues({
    required String pluginId,
    required String sessionId,
    required String backendMessageId,
    required String? invocationId,
    required String name,
    required String? arguments,
    required CommandOrigin origin,
    required MessageTime? time,
    required Iterable<MessagePart> resultParts,
  }) {
    return CommandMessageTimelineCandidate(
      pluginId: pluginId,
      sessionId: sessionId,
      backendMessageId: backendMessageId,
      invocationId: invocationId,
      name: name,
      arguments: arguments,
      origin: origin,
      time: time,
      resultParts: resultParts,
    );
  }
}
