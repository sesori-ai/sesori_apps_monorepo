import "package:acp_plugin/acp_plugin.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "foundation/antigravity_identity.dart";
import "foundation/antigravity_release.dart";
import "models/antigravity_model_catalog.dart";
import "runtime/antigravity_interaction_composer.dart";
import "runtime/antigravity_output_composer.dart";
import "services/antigravity_session_metadata_service.dart";
import "services/antigravity_session_options_service.dart";
import "trackers/antigravity_catalog_tracker.dart";

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
  required final AntigravityCatalogTracker _catalog,
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
  void onConnectionReset() => _catalog.clear();
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
  }) => _options.applyForPrompt(configRepository: configRepository, sessionId: sessionId, modelId: model?.modelID);

  @override
  Future<PluginSessionOptionsDiscoveryResult> getSessionOptions({
    required String projectId,
    required PluginSessionOptionsDiscoveryMode discoveryMode,
  }) async => PluginSessionOptionsDiscoveryResult.observed(
    options: _options.getSessionOptions().copyWith(commands: await getCommands(projectId: projectId)),
  );
  @override
  Future<List<PluginAgent>> getAgents({required String projectId}) async => _options.getSessionOptions().agents;
  @override
  Future<PluginProvidersResult> getProviders({required String projectId}) async =>
      _options.getSessionOptions().providers;

  @override
  Future<void> recoverSessionDirectories() async =>
      registerRecoveredSessionDirectories(batch: await _metadata.recover(geminiHome: _geminiHome));
}
