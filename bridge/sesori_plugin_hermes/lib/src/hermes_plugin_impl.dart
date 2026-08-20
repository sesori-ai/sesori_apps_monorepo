import "package:acp_plugin/acp_plugin.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "hermes_identity.dart";
import "services/hermes_session_options_service.dart";

/// Hermes Agent backend over ACP.
///
/// Hermes is a stock ACP v1 server: `hermes acp` advertises load/list/resume/
/// fork/prompt capabilities and streams turns via `session/update`
/// notifications, so the base [AcpPlugin] machinery owns sessions and turns.
/// This class declares Hermes-specific protocol policies, including excluding
/// interactive terminal setup from headless authentication. Hermes model
/// discovery and its unstable `session/set_model` extension stay isolated in
/// this package. It has no managed runtime (Hermes installs itself; the bridge
/// resolves it on PATH).
class HermesPlugin({
  required super.launchSpec,
  required super.launchDirectory,
  required super.contentMapper,
  required super.eventMapper,
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
  String get clientName => "sesori-bridge";

  @override
  String get clientVersion => "0.0.0";

  /// Hermes provider method ids are dynamic, so there is no fixed preferred
  /// id. [selectAuthMethod] chooses Hermes's first non-terminal provider.
  @override
  String? get authMethodId => null;

  @override
  String? selectAuthMethod({required AcpInitializeResult init}) {
    for (final method in init.authMethods) {
      if (method.type != AcpAuthMethodType.terminal) return method.id;
    }
    return null;
  }

  @override
  Map<String, dynamic>? get initializeCapabilityMeta => null;

  /// Hermes has no `elicitation/create`; permissions arrive as
  /// `session/request_permission`, which the base approval registry handles.
  @override
  bool get supportsFormElicitation => false;

  /// Hermes serializes turns per session (one agent loop per session), so
  /// concurrent sessions may prompt in parallel.
  @override
  bool get serializesPromptsProcessWide => false;

  @override
  bool get cancelsActiveTurnForQueuedInput => false;

  @override
  bool get failsTurnOnSelectionError => true;

  @override
  Duration get sessionCloseSettlementTimeout => const Duration(seconds: 5);

  @override
  void captureSessionConfig(
    AcpNewSessionResult result, {
    String? sessionId,
    bool fromNewSession = false,
  }) => _hermesSessionOptionsService.captureSessionConfig(
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
