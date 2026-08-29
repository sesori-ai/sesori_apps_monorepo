import "package:acp_plugin/acp_plugin.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "api/deepseek_acp_api.dart";
import "deepseek_approval_registry.dart";
import "deepseek_event_mapper.dart";
import "repositories/deepseek_history_repository.dart";
import "services/deepseek_session_options_service.dart";
import "services/deepseek_session_service.dart";

class DeepSeekPlugin({
  required super.launchSpec,
  required super.launchDirectory,
  required DeepSeekEventMapper mapper,
  required final DeepSeekAcpApi api,
  required final DeepSeekHistoryRepository historyRepository,
  required final DeepSeekSessionService deepSeekSessionService,
  required final DeepSeekSessionOptionsService deepSeekSessionOptionsService,
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
  bool get cancelsActiveTurnForQueuedInput => true;

  @override
  AcpApprovalRegistry buildApprovalRegistry(AcpStdioClient client) => DeepSeekApprovalRegistry(
    client: client,
    emit: emitActivityEvent,
    activeSessionResolver: () => activeTurnSessionId,
    api: api,
  );

  @override
  void validateInitializeResult(AcpInitializeResult result) {
    final metadata = result.raw["_meta"];
    final deepSeekMetadata = metadata is Map ? metadata[DeepSeekAcpApi.initializeMetadataKey] : null;
    if (deepSeekMetadata is! Map) throw const FormatException("DeepSeek initialize metadata is missing");
    api.parseInitializeMetadata(deepSeekMetadata.cast<String, dynamic>());
  }

  @override
  void captureSessionConfig(
    AcpNewSessionResult result, {
    required String? sessionId,
    required bool fromNewSession,
  }) => deepSeekSessionOptionsService.captureSessionConfig(
    result,
    sessionId: sessionId,
    fromNewSession: fromNewSession,
  );

  @override
  Future<void> applyTurnSelection({
    required AcpSessionConfigRepository configRepository,
    required String sessionId,
    required ({String providerID, String modelID})? model,
    required PluginSessionVariant? variant,
    required String? agent,
  }) => deepSeekSessionOptionsService.applyTurnSelection(
    configRepository: configRepository,
    sessionId: sessionId,
    model: model,
    variant: variant,
  );

  @override
  Future<PluginSessionOptionsDiscoveryResult> getSessionOptions({
    required String projectId,
    required PluginSessionOptionsDiscoveryMode discoveryMode,
  }) async => await deepSeekSessionOptionsService.getSessionOptions(
    client: await requireConnectedClient(),
    cwd: projectId,
  );

  @override
  Future<List<PluginAgent>> getAgents({required String projectId}) async =>
      await deepSeekSessionOptionsService.listAgents(
        client: await requireConnectedClient(),
        cwd: projectId,
      );

  @override
  Future<PluginProvidersResult> getProviders({required String projectId}) async =>
      await deepSeekSessionOptionsService.listProviders(
        client: await requireConnectedClient(),
        cwd: projectId,
      );

  @override
  Future<List<PluginCommand>> getCommands({required String? projectId}) async =>
      await deepSeekSessionOptionsService.listCommands(
        client: await requireConnectedClient(),
        cwd: projectId ?? launchDirectory,
      );

  // ignore: no_slop_linter/prefer_specific_type, ACP metadata values are heterogeneous
  Map<String, dynamic>? _sessionMetadata(AcpSessionInfo info) {
    final value = info.metadata?[DeepSeekAcpApi.initializeMetadataKey];
    // ignore: no_slop_linter/prefer_specific_type, ACP metadata values are heterogeneous
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

  @override
  Future<PluginSession> renameSession({required String sessionId, required String title}) async =>
      await deepSeekSessionService.rename(
        client: await requireConnectedClient(),
        sessionId: sessionId,
        title: title,
        directory: directoryForSession(sessionId: sessionId),
      );
}
