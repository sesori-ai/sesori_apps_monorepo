import "package:acp_plugin/acp_plugin.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "api/omp_acp_api.dart";
import "models/omp_catalog_models.dart";
import "omp_binary.dart";
import "omp_event_mapper.dart";
import "omp_identity.dart";
import "repositories/omp_catalog_repository.dart";
import "repositories/omp_session_cleanup_repository.dart";
import "repositories/omp_steering_repository.dart";
import "services/omp_catalog_service.dart";
import "services/omp_session_cleanup_service.dart";
import "services/omp_session_options_service.dart";
import "services/omp_steering_service.dart";
import "trackers/omp_catalog_tracker.dart";
import "trackers/omp_compaction_tracker.dart";

/// Oh My Pi backend over ACP.
///
/// OMP replaces an in-flight same-session turn when another `session/prompt`
/// arrives, so a busy follow-up is steered through `_session/steering` when the
/// process advertises it and otherwise uses the shared stop-and-send. It
/// supports standard form elicitation. Independent sessions retain stock ACP's
/// per-session turn lanes, while project-scoped model/mode/thinking catalog and
/// persisted-session cleanup run over isolated scratch processes.
class OmpPlugin._({
  required super.launchSpec,
  required super.launchDirectory,
  required super.eventMapper,
  required super.childSessionTracker,
  required super.commandTracker,
  required final OmpCatalogService _catalogService,
  required final OmpSessionOptionsService _ompSessionOptionsService,
  required final OmpSessionCleanupService _cleanupService,
  required final OmpSteeringService _steeringService,
  required super.processFactory,
}) extends AcpPlugin implements PersistedSessionCleanupApi {
  factory({
    required String binaryPath,
    required String launchDirectory,
    required String? scratchDirectory,
    required AcpProcessFactory processFactory,
    required ServerClock clock,
  }) {
    final launchSpec = OmpBinary.launchSpec(
      binary: binaryPath,
      cwd: launchDirectory,
      sessionDirectory: null,
    );
    final configurationTracker = AcpSessionConfigurationTracker();
    final commandTracker = AcpCommandTracker();
    final childSessionTracker = AcpChildSessionTracker();
    final catalogApi = OmpAcpApi(
      binaryPath: binaryPath,
      processFactory: processFactory,
      logTag: "${OmpPluginIdentity.id}-catalog",
      isolateSessionHistory: true,
      scratchParent: scratchDirectory,
    );
    final catalogRepository = OmpCatalogRepository(api: catalogApi);
    final catalogTracker = OmpCatalogTracker();
    final catalogService = OmpCatalogService(
      repository: catalogRepository,
      tracker: catalogTracker,
      totalTimeout: const Duration(seconds: 20),
    );
    final ompSessionOptionsService = OmpSessionOptionsService(
      catalogService: catalogService,
      tracker: catalogTracker,
      repository: catalogRepository,
      configurationTracker: configurationTracker,
      launchDirectory: launchDirectory,
    );
    final cleanupService = OmpSessionCleanupService(
      repository: OmpSessionCleanupRepository(
        api: OmpAcpApi(
          binaryPath: binaryPath,
          processFactory: processFactory,
          logTag: "${OmpPluginIdentity.id}-cleanup",
          isolateSessionHistory: false,
          scratchParent: scratchDirectory,
        ),
      ),
      launchDirectory: launchDirectory,
      totalTimeout: const Duration(seconds: 20),
      maxPages: 50,
    );
    return OmpPlugin._(
      launchSpec: launchSpec,
      launchDirectory: launchDirectory,
      childSessionTracker: childSessionTracker,
      eventMapper: OmpEventMapper(
        launchDirectory: launchDirectory,
        pluginId: OmpPluginIdentity.id,
        configurationTracker: configurationTracker,
        childSessions: childSessionTracker,
        compactionTracker: OmpCompactionTracker(clock: clock),
      ),
      commandTracker: commandTracker,
      catalogService: catalogService,
      ompSessionOptionsService: ompSessionOptionsService,
      cleanupService: cleanupService,
      steeringService: OmpSteeringService(repository: OmpSteeringRepository(api: catalogApi)),
      processFactory: processFactory,
    );
  }

  this
    : super(
        id: OmpPluginIdentity.id,
        agentDisplayName: OmpPluginIdentity.displayName,
      );

  @override
  String? get authMethodId => OmpBinary.acpAuthMethodId;

  @override
  bool get supportsFormElicitation => true;

  /// From 18.18.9, ACP session deletion persists an empty untitled replacement
  /// session (https://github.com/can1357/oh-my-pi/issues/19068). An entry with
  /// zero messages and no title holds nothing to show: it is that leftover or
  /// a session never prompted, and one Sesori created keeps its bridge row.
  /// A missing count keeps the entry.
  @override
  bool includeListedSession(AcpSessionInfo info) {
    final title = info.title;
    final hasTitle = title != null && title.trim().isNotEmpty;
    return hasTitle || info.metadata?["messageCount"] != 0;
  }

  /// OMP advertises `_session/steering` per process in its `initialize`
  /// result. Without it, follow-ups keep the shared stop-and-send.
  @override
  bool get supportsActiveTurnSteering {
    final result = initializeResult;
    return result != null && _steeringService.supportsSteering(result: result);
  }

  @override
  Future<AcpSteeringOutcome> steerActiveTurn({
    required AcpStdioClient client,
    required String sessionId,
    required List<Map<String, dynamic>> prompt,
  }) => _steeringService.steer(client: client, sessionId: sessionId, prompt: prompt);

  @override
  void captureSessionConfig(
    AcpNewSessionResult result, {
    required String? sessionId,
    required bool fromNewSession,
  }) => _ompSessionOptionsService.captureSessionConfig(
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
    await _ompSessionOptionsService.applyTurnSelection(
      configRepository: configRepository,
      sessionId: sessionId,
      projectId: directoryForSession(sessionId: sessionId),
      model: model,
      variant: variant,
      agent: agent,
    );
  }

  @override
  Future<PluginSessionOptionsDiscoveryResult> getSessionOptions({
    required String projectId,
    required PluginSessionOptionsDiscoveryMode discoveryMode,
  }) async {
    final result = await _ompSessionOptionsService.getSessionOptions(
      projectId: projectId,
      discoveryMode: discoveryMode,
    );
    return switch (result) {
      OmpOptionsObserved(:final options) => PluginSessionOptionsDiscoveryResult.observed(options: options),
      OmpOptionsNoModels() => const PluginSessionOptionsDiscoveryResult.authenticationRequired(
        actionHint: "Open OMP locally, run /login, then retry.",
      ),
      OmpOptionsDiscoveryFailed() => const PluginSessionOptionsDiscoveryResult.failed(),
    };
  }

  @override
  Future<List<PluginCommand>> getCommands({required String? projectId}) =>
      _ompSessionOptionsService.listCommands(projectId: projectId);

  @override
  Future<List<PluginAgent>> getAgents({required String projectId}) =>
      _ompSessionOptionsService.listAgents(projectId: projectId);

  @override
  Future<PluginProvidersResult> getProviders({required String projectId}) =>
      _ompSessionOptionsService.listProviders(projectId: projectId);

  @override
  Future<void> deletePersistedSession({required String backendSessionId}) =>
      _cleanupService.deletePersistedSession(backendSessionId: backendSessionId);

  @override
  Future<void> deleteSession(String sessionId) async {
    await super.deleteSession(sessionId);
    _ompSessionOptionsService.forgetSession(sessionId: sessionId);
  }

  @override
  void onConnectionReset() => _ompSessionOptionsService.resetConnection();

  @override
  Iterable<BridgeSseEvent> mapPromptFailure({
    required String sessionId,
    required Object error,
  }) {
    if (!_isMissingModel(error)) return const [];
    return [
      BridgeSseTuiToastShow(
        sessionID: sessionId,
        title: "Oh My Pi needs a model",
        message: "Open OMP locally, run /login, then retry.",
        variant: "warning",
      ),
    ];
  }

  /// From 18.6.3, OMP refuses to reopen a stored session whose saved model can
  /// no longer be used (renamed id, removed credentials, removed local model)
  /// and fails `session/load`/`session/resume` with an internal error whose
  /// details read `Could not restore model <provider/id>`. Upstream fails
  /// closed on purpose, so explain it rather than show the internal error.
  @override
  String? unrestorableSessionMessage({required AcpRpcException error}) {
    const prefix = "Could not restore model ";
    if (error case AcpRpcException(code: -32603, data: {"details": final String details})
        when details.startsWith(prefix)) {
      final model = details.substring(prefix.length).trim();
      return "${OmpPluginIdentity.displayName} can no longer restore this session's model ($model).";
    }
    return null;
  }

  @override
  Future<void> dispose() async {
    try {
      await _catalogService.dispose();
    } on Object catch (error, stack) {
      Log.w("[${OmpPluginIdentity.id}] failed to dispose catalog service", error, stack);
    }
    try {
      await _cleanupService.dispose();
    } on Object catch (error, stack) {
      Log.w("[${OmpPluginIdentity.id}] failed to dispose cleanup service", error, stack);
    }
    await super.dispose();
  }

  static bool _isMissingModel(Object error) {
    if (error is! AcpRpcException || error.code != -32603) return false;
    final data = error.data;
    if (data is! Map) return false;
    final details = data["details"];
    return details is String && details.startsWith("No model selected.");
  }
}
