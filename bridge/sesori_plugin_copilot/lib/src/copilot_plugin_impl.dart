import "package:acp_plugin/acp_plugin.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "api/copilot_catalog_probe_api.dart";
import "copilot_binary.dart";
import "copilot_identity.dart";
import "repositories/copilot_catalog_repository.dart";
import "services/copilot_session_options_service.dart";

/// GitHub Copilot CLI backend over standard ACP v1.
///
/// Copilot uses the shared ACP transport, session persistence/replay, commands,
/// config-option writes, and permissions without a private protocol dialect.
/// It supports standard cancellation but does not currently forward its
/// `ask_user` interaction over ACP, so form elicitation remains unadvertised.
class CopilotPlugin._({
  required super.launchSpec,
  required super.launchDirectory,
  required super.eventMapper,
  required super.commandTracker,
  required super.sessionOptionsService,
  required CopilotSessionOptionsService copilotSessionOptionsService,
  required super.processFactory,
}) extends AcpPlugin {
  factory({
    required String binaryPath,
    required String launchDirectory,
    required Map<String, String> environment,
    required AcpProcessFactory processFactory,
  }) {
    final configurationTracker = AcpSessionConfigurationTracker();
    final commandTracker = AcpCommandTracker();
    final launchSpec = CopilotBinary.launchSpec(
      binary: binaryPath,
      cwd: launchDirectory,
      environment: environment,
    );
    final copilotSessionOptionsService = CopilotSessionOptionsService(
      commandTracker: commandTracker,
      configurationTracker: configurationTracker,
      repository: CopilotCatalogRepository(
        api: CopilotCatalogProbeApi(
          launchSpec: launchSpec,
          processFactory: processFactory,
        ),
      ),
      launchDirectory: launchDirectory,
      discoveryTimeout: const Duration(seconds: 12),
    );
    return CopilotPlugin._(
      launchSpec: launchSpec,
      launchDirectory: launchDirectory,
      eventMapper: AcpEventMapper(
        launchDirectory: launchDirectory,
        pluginId: CopilotPluginIdentity.id,
        configurationTracker: configurationTracker,
      ),
      commandTracker: commandTracker,
      sessionOptionsService: AcpSessionOptionsService(
        configurationTracker: configurationTracker,
        commandTracker: commandTracker,
        pluginId: CopilotPluginIdentity.id,
        agentDisplayName: CopilotPluginIdentity.displayName,
      ),
      copilotSessionOptionsService: copilotSessionOptionsService,
      processFactory: processFactory,
    );
  }

  this
    : super(
        id: CopilotPluginIdentity.id,
        agentDisplayName: CopilotPluginIdentity.displayName,
      );

  final CopilotSessionOptionsService _copilotSessionOptionsService = copilotSessionOptionsService;

  @override
  String? get authMethodId => CopilotBinary.acpAuthMethodId;

  @override
  String? get authenticationFailureActionHint => super.authenticationFailureActionHint == null
      ? null
      : "Run `copilot login` on the bridge machine, then retry GitHub Copilot.";

  @override
  bool get cancelsActiveTurnForQueuedInput => true;

  @override
  void captureSessionConfig(
    AcpNewSessionResult result, {
    required String? sessionId,
    required bool fromNewSession,
  }) => _copilotSessionOptionsService.captureSessionConfig(
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
  }) => _copilotSessionOptionsService.applyTurnSelection(
    configRepository: configRepository,
    sessionId: sessionId,
    model: model,
    variant: variant,
    agent: agent,
  );

  @override
  Future<PluginSessionOptionsDiscoveryResult> getSessionOptions({
    required String projectId,
    required PluginSessionOptionsDiscoveryMode discoveryMode,
  }) => _discoverOptions(discoveryMode: discoveryMode);

  @override
  Future<List<PluginAgent>> getAgents({required String projectId}) async {
    await _requireOptions();
    return _copilotSessionOptionsService.agents;
  }

  @override
  Future<PluginProvidersResult> getProviders({required String projectId}) async {
    await _requireOptions();
    return _copilotSessionOptionsService.providers;
  }

  @override
  Future<List<PluginCommand>> getCommands({required String? projectId}) async {
    await _requireOptions();
    return _copilotSessionOptionsService.commands;
  }

  @override
  void onConnectionReset() => _copilotSessionOptionsService.resetConnection();

  Future<PluginSessionOptionsDiscoveryResult> _discoverOptions({
    required PluginSessionOptionsDiscoveryMode discoveryMode,
  }) => _copilotSessionOptionsService.getSessionOptions(discoveryMode: discoveryMode);

  Future<void> _requireOptions() async {
    final result = await _discoverOptions(discoveryMode: PluginSessionOptionsDiscoveryMode.reuse);
    if (result is PluginSessionOptionsDiscoveryFailed) {
      throw const PluginOperationException(
        "session/options",
        message: "GitHub Copilot session options could not be discovered",
      );
    }
  }

  @override
  Future<void> dispose() async {
    try {
      await _copilotSessionOptionsService.dispose();
    } on Object catch (error, stack) {
      Log.w("[${CopilotPluginIdentity.id}] failed to dispose session option discovery", error, stack);
    }
    await super.dispose();
  }
}
