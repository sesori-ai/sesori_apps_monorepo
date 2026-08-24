import "package:acp_plugin/acp_plugin.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "api/deepseek_acp_api.dart";
import "deepseek_approval_registry.dart";
import "deepseek_event_mapper.dart";
import "repositories/deepseek_history_repository.dart";

class DeepSeekPlugin({
  required super.launchSpec,
  required super.launchDirectory,
  required DeepSeekEventMapper mapper,
  required final DeepSeekAcpApi api,
  required final DeepSeekHistoryRepository historyRepository,
  required super.commandTracker,
  required super.sessionOptionsService,
  required super.processFactory,
}) extends AcpPlugin {
  this
    : super(
        id: mapper.pluginId,
        agentDisplayName: "DeepSeek",
        eventMapper: mapper,
      );

  @override
  AcpApprovalRegistry buildApprovalRegistry(AcpStdioClient client) => DeepSeekApprovalRegistry(
    client: client,
    emit: emitActivityEvent,
    onFireAndForgetNotification: handleAgentNotification,
    activeSessionResolver: () => activeTurnSessionId,
    api: api,
  );

  Map<String, dynamic>? _sessionMetadata(AcpSessionInfo info) {
    final value = info.metadata?[DeepSeekAcpApi.initializeMetadataKey];
    return value is Map ? value.cast<String, dynamic>() : null;
  }

  @override
  String? sessionParentId(AcpSessionInfo info) {
    final value = _sessionMetadata(info)?["parentSessionId"];
    return value is String && value.trim().isNotEmpty ? value : null;
  }

  @override
  int? sessionCreatedAtMs(AcpSessionInfo info) {
    final createdAt = _sessionMetadata(info)?["createdAt"];
    return switch (createdAt) {
      final num value => value.round(),
      final String value => DateTime.tryParse(value)?.millisecondsSinceEpoch,
      _ => super.sessionCreatedAtMs(info),
    };
  }

  @override
  Map<String, dynamic>? outboundPromptMeta({
    required String sessionId,
    required String messageId,
  }) => {
    DeepSeekAcpApi.initializeMetadataKey: {"messageId": messageId},
  };

  @override
  Future<List<PluginSession>> getChildSessions(String sessionId) async => [
    for (final session in await listAllSessions(knownDirectories: const {}))
      if (session.parentID == sessionId) session,
  ];

  @override
  Future<List<PluginMessageWithParts>> getSessionMessages(String sessionId) async {
    final client = await requireConnectedClient();
    return await historyRepository.getMessages(client: client, sessionId: sessionId);
  }
}
