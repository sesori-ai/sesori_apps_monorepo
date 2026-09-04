import "package:acp_plugin/acp_plugin.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "hermes_identity.dart";
import "services/hermes_session_options_service.dart";

/// Hermes Agent backend over ACP.
///
/// Hermes is an ACP v1 server: `hermes acp` advertises load/list/resume/
/// fork/prompt capabilities and streams turns via `session/update`
/// notifications. It uses standard ACP cancellation for stop-and-send
/// follow-ups; the remaining stock policies include per-session serialization,
/// no form elicitation or capability meta, first non-terminal authentication,
/// and fail-closed selection. Only Hermes model discovery and its unstable
/// `session/set_model` extension are layered on here, isolated in this package.
/// It has no managed runtime (Hermes installs itself; the bridge resolves it on
/// PATH).
class HermesPlugin({
  required super.launchSpec,
  required super.launchDirectory,
  required super.eventMapper,
  required super.childSessionTracker,
  required super.commandTracker,
  required super.sessionOptionsService,
  required super.processFactory,
  required final HermesSessionOptionsService _hermesSessionOptionsService,
}) extends AcpPlugin {
  this
    : super(
        id: HermesPluginIdentity.id,
        agentDisplayName: HermesPluginIdentity.displayName,
      );

  @override
  void captureSessionConfig(
    AcpNewSessionResult result, {
    required String? sessionId,
    required bool fromNewSession,
  }) => _hermesSessionOptionsService.captureSessionConfig(
    result,
    sessionId: sessionId,
    fromNewSession: fromNewSession,
  );

  /// Hermes selects models through its `session/set_model` extension, so the
  /// standard config repository is unused; the write goes through the Hermes
  /// repository over the live client.
  @override
  Future<void> applyTurnSelection({
    required AcpSessionConfigRepository configRepository,
    required String sessionId,
    required ({String providerID, String modelID})? model,
    required PluginSessionVariant? variant,
    required String? agent,
  }) async {
    final liveClient = client;
    if (liveClient == null) throw StateError("Hermes ACP client is not connected");
    await _hermesSessionOptionsService.applyTurnSelection(
      liveClient: liveClient,
      sessionId: sessionId,
      model: model,
    );
  }

  @override
  Future<PluginSessionOptionsDiscoveryResult> getSessionOptions({
    required String projectId,
    required PluginSessionOptionsDiscoveryMode discoveryMode,
  }) => _hermesSessionOptionsService.getSessionOptions(discoveryMode: discoveryMode);

  @override
  Future<List<PluginAgent>> getAgents({required String projectId}) => _hermesSessionOptionsService.listAgents();

  @override
  Future<PluginProvidersResult> getProviders({required String projectId}) =>
      _hermesSessionOptionsService.listProviders();

  @override
  Future<void> deleteSession(String sessionId) async {
    await super.deleteSession(sessionId);
    _hermesSessionOptionsService.forgetSession(sessionId: sessionId);
  }

  @override
  void onConnectionReset() => _hermesSessionOptionsService.resetConnection();

  @override
  Future<void> dispose() async {
    try {
      await _hermesSessionOptionsService.dispose();
    } on Object catch (error, stackTrace) {
      Log.w("[${HermesPluginIdentity.id}] failed to dispose session options service", error, stackTrace);
    }
    await super.dispose();
  }
}
