import "dart:async";
import "dart:io" show Directory;

import "package:acp_plugin/acp_plugin.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "api/omp_acp_api.dart";
import "models/omp_catalog_models.dart";
import "omp_binary.dart";
import "omp_identity.dart";
import "repositories/omp_catalog_repository.dart";
import "repositories/omp_session_cleanup_repository.dart";
import "services/omp_catalog_service.dart";
import "services/omp_session_cleanup_service.dart";
import "services/omp_session_options_service.dart";
import "trackers/omp_catalog_tracker.dart";

/// Oh My Pi backend over ACP.
///
/// OMP diverges from stock ACP in four policies: it serializes every prompt
/// process-wide, replaces an in-flight turn when another input arrives,
/// supports standard form elicitation, and can stream agent-initiated async-job
/// turns after `session/prompt` has returned. Its project-scoped
/// model/mode/thinking catalog and persisted-session cleanup run over isolated
/// scratch processes.
class OmpPlugin._({
  required super.launchSpec,
  required super.launchDirectory,
  required super.eventMapper,
  required super.commandTracker,
  required super.sessionOptionsService,
  required final OmpCatalogService _catalogService,
  required final OmpSessionOptionsService _ompSessionOptionsService,
  required final OmpSessionCleanupService _cleanupService,
  required final Duration _agentInitiatedTurnQuietPeriod,
  super.processFactory,
}) extends AcpPlugin implements PersistedSessionCleanupApi {
  /// ACP v1 has no completion marker for OMP's agent-initiated turns. Silence
  /// is therefore the only available boundary; a later update starts another
  /// turn if a slow provider exceeds this window.
  static const Duration defaultAgentInitiatedTurnQuietPeriod = Duration(minutes: 2);

  factory({
    String binaryPath = OmpBinary.defaultBinary,
    String? launchDirectory,
    String? scratchDirectory,
    required AcpProcessFactory processFactory,
    required Duration agentInitiatedTurnQuietPeriod,
  }) {
    final cwd = launchDirectory ?? Directory.current.path;
    final launchSpec = OmpBinary.launchSpec(
      binary: binaryPath,
      cwd: cwd,
      sessionDirectory: null,
    );
    final configurationTracker = AcpSessionConfigurationTracker();
    final commandTracker = AcpCommandTracker();
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
      maxModels: 24,
    );
    final ompSessionOptionsService = OmpSessionOptionsService(
      catalogService: catalogService,
      tracker: catalogTracker,
      repository: catalogRepository,
      configurationTracker: configurationTracker,
      launchDirectory: cwd,
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
      launchDirectory: cwd,
      totalTimeout: const Duration(seconds: 20),
      maxPages: 50,
    );
    return OmpPlugin._(
      launchSpec: launchSpec,
      launchDirectory: cwd,
      eventMapper: AcpEventMapper(
        launchDirectory: cwd,
        pluginId: OmpPluginIdentity.id,
        configurationTracker: configurationTracker,
      ),
      commandTracker: commandTracker,
      sessionOptionsService: AcpSessionOptionsService(
        configurationTracker: configurationTracker,
        commandTracker: commandTracker,
        pluginId: OmpPluginIdentity.id,
        agentDisplayName: OmpPluginIdentity.displayName,
      ),
      catalogService: catalogService,
      ompSessionOptionsService: ompSessionOptionsService,
      cleanupService: cleanupService,
      agentInitiatedTurnQuietPeriod: agentInitiatedTurnQuietPeriod,
      processFactory: processFactory,
    );
  }

  final Map<String, _OmpAgentInitiatedTurn> _agentInitiatedTurns = {};
  final Set<String> _agentInitiatedTurnFences = {};

  this
    : super(
        id: OmpPluginIdentity.id,
        agentDisplayName: OmpPluginIdentity.displayName,
      );

  @override
  String? get authMethodId => OmpBinary.acpAuthMethodId;

  @override
  bool get supportsFormElicitation => true;

  @override
  bool get serializesPromptsProcessWide => true;

  @override
  bool get cancelsActiveTurnForQueuedInput => true;

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
      OmpOptionsNoModels() => () {
        emitEvent(_missingModelToast);
        return const PluginSessionOptionsDiscoveryResult.failed();
      }(),
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
    _agentInitiatedTurnFences.remove(sessionId);
    _forgetAgentInitiatedTurn(sessionId: sessionId);
    await super.deleteSession(sessionId);
    // Active deletion calls the overridden abort path, which re-adds the
    // fence while the session settles; a successful delete owns final cleanup.
    _agentInitiatedTurnFences.remove(sessionId);
    _ompSessionOptionsService.forgetSession(sessionId: sessionId);
  }

  @override
  void onLiveAgentNotification(AcpNotification notification) {
    if (notification.method != AcpMethods.sessionUpdate) return;
    final sessionId = notification.params["sessionId"];
    final update = notification.params["update"];
    if (sessionId is! String || sessionId.isEmpty || update is! Map) return;
    if (_agentInitiatedTurnFences.contains(sessionId)) return;
    final kind = AcpSessionUpdateKind.parse(update["sessionUpdate"]);
    if (!kind.carriesAgentWork || hasBridgePromptTurn(sessionId: sessionId)) return;

    final observedAt = DateTime.now().millisecondsSinceEpoch;
    final opened = markAgentInitiatedTurnActive(
      sessionId: sessionId,
      observedAt: observedAt,
    );
    var turn = _agentInitiatedTurns[sessionId];
    if (opened || turn == null) {
      turn?.timer?.cancel();
      turn = _OmpAgentInitiatedTurn(firstObservedAt: observedAt);
      _agentInitiatedTurns[sessionId] = turn;
    }
    turn.lastObservedAt = observedAt;
    turn.timer?.cancel();
    final trackedTurn = turn;
    turn.timer = Timer(
      _agentInitiatedTurnQuietPeriod,
      () => _settleAgentInitiatedTurn(sessionId: sessionId, expected: trackedTurn),
    );
  }

  void _settleAgentInitiatedTurn({required String sessionId, required _OmpAgentInitiatedTurn expected}) {
    if (!identical(_agentInitiatedTurns[sessionId], expected)) return;
    _agentInitiatedTurns.remove(sessionId);
    expected.timer?.cancel();
    markAgentInitiatedTurnIdle(
      sessionId: sessionId,
      lastObservedAt: expected.lastObservedAt > expected.firstObservedAt ? expected.lastObservedAt : null,
    );
  }

  void _forgetAgentInitiatedTurn({required String sessionId}) {
    _agentInitiatedTurns.remove(sessionId)?.timer?.cancel();
  }

  @override
  void onBridgePromptTurnStarted({required String sessionId}) {
    _agentInitiatedTurnFences.remove(sessionId);
    _forgetAgentInitiatedTurn(sessionId: sessionId);
  }

  @override
  Future<void> abortSession({required String sessionId}) async {
    _agentInitiatedTurnFences.add(sessionId);
    _forgetAgentInitiatedTurn(sessionId: sessionId);
    await super.abortSession(sessionId: sessionId);
  }

  void _clearAgentInitiatedTurnTimers() {
    for (final turn in _agentInitiatedTurns.values) {
      turn.timer?.cancel();
    }
    _agentInitiatedTurns.clear();
    _agentInitiatedTurnFences.clear();
  }

  @override
  void onConnectionReset() {
    _clearAgentInitiatedTurnTimers();
    _ompSessionOptionsService.resetConnection();
  }

  @override
  Iterable<BridgeSseEvent> mapPromptFailure({
    required String sessionId,
    required Object error,
  }) {
    if (!_isMissingModel(error)) return const [];
    return const [_missingModelToast];
  }

  @override
  Future<void> dispose() async {
    _clearAgentInitiatedTurnTimers();
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

  static const BridgeSseTuiToastShow _missingModelToast = BridgeSseTuiToastShow(
    title: "Oh My Pi needs a model",
    message: "Open OMP locally, run /login, then retry.",
    variant: "warning",
  );

  static bool _isMissingModel(Object error) {
    if (error is! AcpRpcException || error.code != -32603) return false;
    final data = error.data;
    if (data is! Map) return false;
    final details = data["details"];
    return details is String && details.startsWith("No model selected.");
  }
}

class _OmpAgentInitiatedTurn({required final int firstObservedAt}) {
  int lastObservedAt = 0;
  Timer? timer;
}
