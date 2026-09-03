import "package:acp_plugin/acp_plugin.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "api/grok_acp_api.dart";
import "api/grok_session_store_api.dart";
import "grok_binary.dart";
import "grok_event_mapper.dart";
import "grok_identity.dart";
import "repositories/grok_catalog_repository.dart";
import "repositories/grok_session_catalog_repository.dart";
import "repositories/grok_session_config_repository.dart";
import "services/grok_session_options_service.dart";
import "services/grok_session_service.dart";
import "trackers/grok_catalog_tracker.dart";

/// Grok Build backend over ACP v1 with plugin-local legacy model selection.
class GrokPlugin._({
  required super.launchSpec,
  required super.launchDirectory,
  required super.eventMapper,
  required super.childSessionTracker,
  required super.commandTracker,
  required super.sessionOptionsService,
  required super.processFactory,
  required GrokSessionOptionsService grokSessionOptionsService,
  required final GrokSessionService _sessionService,
}) extends AcpPlugin {
  factory({
    required String binaryPath,
    required String launchDirectory,
    required Map<String, String> environment,
    required AcpProcessFactory processFactory,
  }) {
    final configurationTracker = AcpSessionConfigurationTracker();
    final commandTracker = AcpCommandTracker();
    final childSessionTracker = AcpChildSessionTracker();
    final api = GrokAcpApi(
      binaryPath: binaryPath,
      processFactory: processFactory,
      environment: environment,
    );
    final grokSessionOptionsService = GrokSessionOptionsService(
      catalogRepository: GrokCatalogRepository(api: api),
      configRepository: GrokSessionConfigRepository(api: api),
      catalogTracker: GrokCatalogTracker(),
      configurationTracker: configurationTracker,
      commandTracker: commandTracker,
      launchDirectory: launchDirectory,
      pluginId: GrokPluginIdentity.id,
      displayName: GrokPluginIdentity.displayName,
      discoveryTimeout: const Duration(seconds: 15),
    );
    final sessionCatalogRepository = GrokSessionCatalogRepository(
      api: GrokSessionStoreApi.forHome(
        environment: environment,
        pluginId: GrokPluginIdentity.id,
      ),
    );
    return GrokPlugin._(
      launchSpec: GrokBinary.launchSpec(
        binary: binaryPath,
        cwd: launchDirectory,
        environment: environment,
      ),
      launchDirectory: launchDirectory,
      childSessionTracker: childSessionTracker,
      eventMapper: GrokEventMapper(
        launchDirectory: launchDirectory,
        pluginId: GrokPluginIdentity.id,
        configurationTracker: configurationTracker,
        childSessions: childSessionTracker,
      ),
      commandTracker: commandTracker,
      sessionOptionsService: AcpSessionOptionsService(
        configurationTracker: configurationTracker,
        commandTracker: commandTracker,
        pluginId: GrokPluginIdentity.id,
        agentDisplayName: GrokPluginIdentity.displayName,
      ),
      processFactory: processFactory,
      grokSessionOptionsService: grokSessionOptionsService,
      sessionService: GrokSessionService(
        catalogRepository: sessionCatalogRepository,
        liveTracker: childSessionTracker,
      ),
    );
  }

  this
    : super(
        id: GrokPluginIdentity.id,
        agentDisplayName: GrokPluginIdentity.displayName,
      );

  final GrokSessionOptionsService _grokSessionOptionsService = grokSessionOptionsService;

  @override
  Set<String> get authMethodAllowlist => GrokAcpApi.headlessAuthMethodIds;

  @override
  String? get authenticationFailureActionHint => super.authenticationFailureActionHint == null
      ? null
      : "Run `grok login` or configure a headless Grok credential locally, then retry.";

  @override
  void validateInitializeResult(AcpInitializeResult result) =>
      _grokSessionOptionsService.validateInitializeResult(result: result);

  @override
  void captureLiveInitializeResult(AcpInitializeResult result) =>
      _grokSessionOptionsService.captureInitializeResult(result: result);

  @override
  void captureSessionConfig(
    AcpNewSessionResult result, {
    required String? sessionId,
    required bool fromNewSession,
  }) => _grokSessionOptionsService.captureSessionConfig(
    result: result,
    sessionId: sessionId,
    fromNewSession: fromNewSession,
  );

  @override
  String? replayVariantForSession({required String sessionId}) =>
      _grokSessionOptionsService.reasoningEffortForSession(sessionId: sessionId);

  @override
  Future<void> validateTurnSelection({
    required String operation,
    required ({String providerID, String modelID})? model,
    required PluginSessionVariant? variant,
    required String? agent,
  }) async => _grokSessionOptionsService.validateTurnSelection(
    operation: operation,
    model: model,
    variant: variant,
    agent: agent,
  );

  @override
  Future<void> applyTurnSelection({
    required AcpSessionConfigRepository configRepository,
    required String sessionId,
    required ({String providerID, String modelID})? model,
    required PluginSessionVariant? variant,
    required String? agent,
  }) async {
    final liveClient = client;
    if (liveClient == null) throw StateError("Grok ACP client is not connected");
    await _grokSessionOptionsService.applyTurnSelection(
      liveClient: liveClient,
      sessionId: sessionId,
      model: model,
      variant: variant,
    );
  }

  @override
  Future<PluginSessionOptionsDiscoveryResult> getSessionOptions({
    required String projectId,
    required PluginSessionOptionsDiscoveryMode discoveryMode,
  }) => _grokSessionOptionsService.getSessionOptions(discoveryMode: discoveryMode);

  @override
  Future<List<PluginAgent>> getAgents({required String projectId}) => _grokSessionOptionsService.listAgents();

  @override
  Future<PluginProvidersResult> getProviders({required String projectId}) => _grokSessionOptionsService.listProviders();

  @override
  void onConnectionReset() => _grokSessionOptionsService.resetConnection();

  @override
  bool isResumeReplayNotification(AcpNotification notification) =>
      super.isResumeReplayNotification(notification) || notification.method == GrokEventMapper.sessionUpdateMethod;

  // Grok's `session/list` is verified to return roots only. Child parentage is
  // added by [_sessionService] after the root list is mapped, avoiding a
  // persisted-tree scan for every root through the generic parent hook.
  @override
  Future<List<PluginSession>> listAllSessions({required Set<String> knownDirectories}) async {
    final listedSessions = await super.listAllSessions(knownDirectories: knownDirectories);
    final listedById = {for (final session in listedSessions) session.id: session};
    final sessions = _sessionService.includeChildrenInAllSessions(sessions: listedSessions);
    for (final session in sessions) {
      final listed = listedById[session.id];
      if (listed == null || listed.directory != session.directory) {
        attributeSessionDirectory(sessionId: session.id, directory: session.directory);
      }
    }
    return sessions;
  }

  @override
  Future<List<PluginSession>> getChildSessions(String sessionId) async => _sessionService.childSessions(
    rootSessionId: sessionId,
    fallbackDirectory: directoryForSession(sessionId: sessionId),
  );

  @override
  Future<void> deleteSession(String sessionId) async {
    if (childSessionTracker.isRunningChild(sessionId: sessionId) ||
        childSessionTracker.hasActiveWorkForRoot(sessionId: sessionId)) {
      throw const PluginOperationException(
        "deleteSession",
        message: "A Grok session with active sub-agent work must finish or be stopped before deletion",
      );
    }
    await super.deleteSession(sessionId);
  }
}
