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

class OmpPlugin extends AcpPlugin implements PersistedSessionCleanupApi {
  factory OmpPlugin({
    String binaryPath = OmpBinary.defaultBinary,
    String? launchDirectory,
    String? scratchDirectory,
    required AcpProcessFactory processFactory,
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
    const contentMapper = AcpContentMapper();
    return OmpPlugin._(
      launchSpec: launchSpec,
      launchDirectory: cwd,
      contentMapper: contentMapper,
      eventMapper: AcpEventMapper(
        launchDirectory: cwd,
        agentId: OmpPluginIdentity.id,
        pluginId: OmpPluginIdentity.id,
        configurationTracker: configurationTracker,
        contentMapper: contentMapper,
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
      processFactory: processFactory,
    );
  }

  OmpPlugin._({
    required super.launchSpec,
    required super.launchDirectory,
    required super.contentMapper,
    required super.eventMapper,
    required super.commandTracker,
    required super.sessionOptionsService,
    required OmpCatalogService catalogService,
    required OmpSessionOptionsService ompSessionOptionsService,
    required OmpSessionCleanupService cleanupService,
    super.processFactory,
  }) : _catalogService = catalogService,
       _ompSessionOptionsService = ompSessionOptionsService,
       _cleanupService = cleanupService,
       super(
         id: OmpPluginIdentity.id,
         agentDisplayName: OmpPluginIdentity.displayName,
       );

  final OmpCatalogService _catalogService;
  final OmpSessionOptionsService _ompSessionOptionsService;
  final OmpSessionCleanupService _cleanupService;

  @override
  String get clientName => "sesori-bridge";

  @override
  String get clientVersion => "0.0.0";

  @override
  String? get authMethodId => "agent";

  @override
  Map<String, dynamic>? get initializeCapabilityMeta => null;

  @override
  bool get supportsFormElicitation => true;

  @override
  bool get serializesPromptsProcessWide => true;

  @override
  bool get failsTurnOnSelectionError => true;

  @override
  Duration get sessionCloseSettlementTimeout => const Duration(seconds: 5);

  @override
  void captureSessionConfig(
    AcpNewSessionResult result, {
    String? sessionId,
    bool fromNewSession = false,
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
      projectId: directoryForSession(sessionId),
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
    return const [_missingModelToast];
  }

  @override
  Future<void> dispose() async {
    try {
      await _catalogService.dispose();
    } on Object catch (error, stack) {
      Log.w("[omp] failed to dispose catalog service", error, stack);
    }
    try {
      await _cleanupService.dispose();
    } on Object catch (error, stack) {
      Log.w("[omp] failed to dispose cleanup service", error, stack);
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
