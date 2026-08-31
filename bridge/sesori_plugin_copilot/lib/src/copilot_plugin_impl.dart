import "package:acp_plugin/acp_plugin.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "api/copilot_catalog_probe_api.dart";
import "copilot_binary.dart";
import "copilot_identity.dart";
import "repositories/copilot_catalog_repository.dart";
import "services/copilot_session_options_service.dart";

/// GitHub Copilot CLI backend over standard ACP v1.
///
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
  @override
  bool get permitsDeviceCanvasHttpMcp => true;

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
          client: AcpStdioClient(
            launchSpec: launchSpec,
            processFactory: processFactory,
            logTag: "copilot-catalog",
          ),
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
  String? get authenticationFailureActionHint =>
      super.authenticationFailureActionHint == null ? null : CopilotBinary.loginActionHint;

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
  Future<void> validateTurnSelection({
    required String operation,
    required ({String providerID, String modelID})? model,
    required PluginSessionVariant? variant,
    required String? agent,
  }) async {
    if (model == null && variant == null && agent == null) return;
    final reasoningModelId = model?.providerID == CopilotPluginIdentity.id ? model?.modelID : null;
    if (!_copilotSessionOptionsService.hasSnapshot) {
      await _requireOptions(
        discoveryMode: PluginSessionOptionsDiscoveryMode.refresh,
        reasoningModelId: reasoningModelId,
      );
    }
    if (variant != null && !_copilotSessionOptionsService.hasReasoningForModel(modelId: reasoningModelId)) {
      await _requireOptions(
        discoveryMode: PluginSessionOptionsDiscoveryMode.refresh,
        reasoningModelId: reasoningModelId,
      );
    }
    _copilotSessionOptionsService.validateTurnSelection(
      operation: operation,
      model: model,
      variant: variant,
      agent: agent,
    );
  }

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
  }) => _discoverOptions(discoveryMode: discoveryMode, reasoningModelId: null);

  @override
  Future<List<PluginAgent>> getAgents({required String projectId}) async {
    await _requireOptions(discoveryMode: PluginSessionOptionsDiscoveryMode.reuse, reasoningModelId: null);
    return _copilotSessionOptionsService.agents;
  }

  @override
  Future<PluginProvidersResult> getProviders({required String projectId}) async {
    await _requireOptions(discoveryMode: PluginSessionOptionsDiscoveryMode.reuse, reasoningModelId: null);
    return _copilotSessionOptionsService.providers;
  }

  @override
  Future<List<PluginCommand>> getCommands({required String? projectId}) async {
    await _requireOptions(discoveryMode: PluginSessionOptionsDiscoveryMode.reuse, reasoningModelId: null);
    return _copilotSessionOptionsService.commands;
  }

  @override
  void onConnectionReset() => _copilotSessionOptionsService.resetConnection();

  Future<PluginSessionOptionsDiscoveryResult> _discoverOptions({
    required PluginSessionOptionsDiscoveryMode discoveryMode,
    required String? reasoningModelId,
  }) => _copilotSessionOptionsService.getSessionOptions(
    discoveryMode: discoveryMode,
    reasoningModelId: reasoningModelId,
  );

  Future<void> _requireOptions({
    required PluginSessionOptionsDiscoveryMode discoveryMode,
    required String? reasoningModelId,
  }) async {
    final result = await _discoverOptions(discoveryMode: discoveryMode, reasoningModelId: reasoningModelId);
    if (result is PluginSessionOptionsDiscoveryFailed) {
      final failure = _copilotSessionOptionsService.lastDiscoveryFailure;
      if (failure == null) {
        throw const PluginOperationException(
          "session/options",
          message: "GitHub Copilot session options could not be discovered",
        );
      }
      Error.throwWithStackTrace(failure.error, failure.stack);
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
