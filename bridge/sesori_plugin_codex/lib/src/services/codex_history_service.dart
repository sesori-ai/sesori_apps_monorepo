import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "../codex_metadata_repository.dart";
import "../repositories/codex_message_repository.dart";

/// Coordinates rollout history with project-scoped command metadata.
class CodexHistoryService {
  CodexHistoryService({
    required CodexMessageRepository messageRepository,
    required CodexMetadataRepository metadataRepository,
  }) : _messageRepository = messageRepository,
       _metadataRepository = metadataRepository;

  final CodexMessageRepository _messageRepository;
  final CodexMetadataRepository _metadataRepository;

  List<PluginMessageWithParts> getMessages({
    required String sessionId,
    required String projectId,
    required List<PluginCommandInvocationContext> acceptedCommands,
  }) {
    final commandNames = _metadataRepository.getCommands(projectId: projectId).map((command) => command.name).toSet();
    return _messageRepository.getMessages(
      sessionId: sessionId,
      acceptedCommands: acceptedCommands,
      knownCommandNames: commandNames,
    );
  }
}
