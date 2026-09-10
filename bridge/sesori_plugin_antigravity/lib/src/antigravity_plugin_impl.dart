import "package:acp_plugin/acp_plugin.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "foundation/antigravity_identity.dart";
import "foundation/antigravity_release.dart";
import "models/antigravity_model_catalog.dart";
import "repositories/antigravity_catalog_repository.dart";
import "runtime/antigravity_interaction_composer.dart";
import "runtime/antigravity_output_composer.dart";
import "services/antigravity_session_metadata_service.dart";
import "services/antigravity_session_options_service.dart";

/// Persistent ACP plugin. All processes, turns and pending input stay
/// owned by the existing ACP lifecycle; the composition root injects all peers.
class AntigravityPlugin({
  required super.launchSpec,
  required super.launchDirectory,
  required super.eventMapper,
  required super.childSessionTracker,
  required super.commandTracker,
  required super.sessionOptionsService,
  required super.processFactory,
  required final AntigravitySessionOptionsService _options,
  required final AntigravitySessionMetadataService _metadata,
  required final String _geminiHome,
  required final AntigravityInteractionComposer _interactions,
  required final AntigravityOutputComposer _output,
}) extends AcpPlugin {
  this : super(id: AntigravityIdentity.pluginId, agentDisplayName: AntigravityIdentity.displayName);

  @override
  Set<String> get authMethodAllowlist => const {AntigravityRelease.personalOauthMethodId};
  @override
  AcpResidencyPreference get residencyPreference => AcpResidencyPreference.resumeFirst;
  @override
  String? get authenticationFailureActionHint =>
      super.authenticationFailureActionHint == null ? null : AntigravityOutputComposer.authenticationHint;
  @override
  AcpOutputInterceptors createOutputInterceptors() => _output.compose();
  @override
  // ignore: no_slop_linter/prefer_specific_type, identity-preserving initialization error mapping
  Object mapInitializationFailure({required Object error}) => _output.mapInitializationFailure(error: error);
  @override
  AcpPendingRegistry<Object> buildApprovalRegistry({required AcpStdioClient client}) =>
      _interactions.compose(client: client, emit: emitActivityEvent);
  @override
  void onConnectionReset() => _options.resetConnection();
  @override
  void captureSessionConfig(AcpNewSessionResult result, {required String? sessionId, required bool fromNewSession}) {
    final capturedSessionId = sessionId ?? result.sessionId;
    if (capturedSessionId.isEmpty) throw StateError("Antigravity session configuration has no session ID");
    _options.capture(
      result: result,
      sessionId: capturedSessionId,
      source: fromNewSession ? AntigravityCatalogSource.newSession : AntigravityCatalogSource.existingSession,
    );
  }

  @override
  Future<void> validateTurnSelection({
    required String operation,
    required ({String providerID, String modelID})? model,
    required PluginSessionVariant? variant,
    required String? agent,
  }) async => _options.validateSelection(
    operation: operation,
    providerId: model?.providerID,
    modelId: model?.modelID,
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
  }) => _options.applyForPrompt(
    configRepository: configRepository,
    sessionId: sessionId,
    modelId: model?.modelID,
    variant: variant,
  );

  @override
  String? replayVariantForSession({required String sessionId}) => eventMapper.variantForSession(sessionId: sessionId);

  @override
  Future<PluginSessionOptionsDiscoveryResult> getSessionOptions({
    required String projectId,
    required PluginSessionOptionsDiscoveryMode discoveryMode,
  }) async {
    final result = await _discover(discoveryMode: discoveryMode);
    if (result is! PluginSessionOptionsDiscoveryObserved) return result;
    return PluginSessionOptionsDiscoveryResult.observed(
      options: result.options.copyWith(commands: await getCommands(projectId: projectId)),
    );
  }

  @override
  Future<List<PluginAgent>> getAgents({required String projectId}) async {
    await _discover(discoveryMode: PluginSessionOptionsDiscoveryMode.reuse);
    return _options.getSessionOptions().agents;
  }

  @override
  Future<PluginProvidersResult> getProviders({required String projectId}) async {
    await _discover(discoveryMode: PluginSessionOptionsDiscoveryMode.reuse);
    return _options.getSessionOptions().providers;
  }

  Future<PluginSessionOptionsDiscoveryResult> _discover({
    required PluginSessionOptionsDiscoveryMode discoveryMode,
  }) => _options.discover(
    discoveryMode: discoveryMode,
    repositoryProvider: () async => AntigravityCatalogRepository(
      api: AcpAgentApi(client: await requireConnectedClient()),
    ),
  );

  @override
  Future<List<PluginSession>> listAllSessions({required Set<String> knownDirectories}) async =>
      _withoutDiscoverySessions(await super.listAllSessions(knownDirectories: knownDirectories));

  @override
  Future<List<PluginSession>> getSessions({
    required String projectId,
    required int? start,
    required int? limit,
  }) async {
    final visible = _withoutDiscoverySessions(
      await super.getSessions(projectId: projectId, start: null, limit: null),
    );
    final from = start ?? 0;
    if (from >= visible.length) return const [];
    final until = limit == null ? visible.length : (from + limit).clamp(0, visible.length);
    return visible.sublist(from, until);
  }

  List<PluginSession> _withoutDiscoverySessions(List<PluginSession> sessions) => [
    for (final session in sessions)
      if (!_options.isDiscoverySession(sessionId: session.id, directory: session.directory)) session,
  ];

  @override
  Future<void> recoverSessionDirectories() async {
    final recovered = await _metadata.recover(geminiHome: _geminiHome);
    registerRecoveredSessionDirectories(
      batch: AcpSessionDirectoryBatch(
        directories: {
          for (final entry in recovered.directories.entries)
            if (!_options.isDiscoverySession(sessionId: entry.key, directory: entry.value)) entry.key: entry.value,
        },
      ),
    );
  }
}
