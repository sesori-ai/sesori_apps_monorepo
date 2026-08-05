import "dart:io" show Directory;

import "package:acp_plugin/acp_plugin.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart" show Harness;

import "api/cursor_catalog_probe_api.dart";
import "cursor_approval_registry.dart";
import "cursor_binary.dart";
import "cursor_event_mapper.dart";
import "models/cursor_catalog_models.dart";
import "repositories/cursor_catalog_repository.dart";
import "repositories/cursor_generated_image_reader.dart";
import "services/cursor_catalog_service.dart";
import "services/cursor_session_cleanup_service.dart";
import "services/cursor_session_options_service.dart";
import "trackers/cursor_catalog_tracker.dart";

/// Cursor backend over ACP plus Cursor's config-option model picker.
class CursorPlugin extends AcpPlugin implements PersistedSessionCleanupApi {
  static final String pluginId = Harness.cursor.name;
  static const String _providerId = "cursor";

  factory CursorPlugin({
    String binaryPath = CursorBinary.defaultBinary,
    String? launchDirectory,
    String? apiEndpoint,
    AcpProcessFactory? processFactory,
    required CursorSessionCleanupService sessionCleanupService,
  }) {
    final cwd = launchDirectory ?? Directory.current.path;
    final launchSpec = CursorBinary.launchSpec(
      binary: binaryPath,
      cwd: cwd,
      apiEndpoint: apiEndpoint,
    );
    final catalogApi = CursorCatalogProbeApi(
      client: AcpStdioClient(
        launchSpec: launchSpec,
        processFactory: processFactory,
        logTag: "$pluginId-catalog",
      ),
    );
    final catalogRepository = CursorCatalogRepository(
      api: catalogApi,
      launchScope: cwd,
    );
    final catalogTracker = CursorCatalogTracker();
    final commandTracker = AcpCommandTracker();
    final stagedCommandTracker = AcpCommandTracker();
    final configurationTracker = AcpSessionConfigurationTracker();
    const contentMapper = AcpContentMapper();
    final acpSessionOptionsService = AcpSessionOptionsService(
      configurationTracker: configurationTracker,
      commandTracker: commandTracker,
      pluginId: pluginId,
      agentDisplayName: "Cursor",
    );
    final catalogCommandListener = AcpCommandListener(
      notifications: catalogApi.notifications,
      tracker: stagedCommandTracker,
    );
    final catalogService = CursorCatalogService(
      repository: catalogRepository,
      tracker: catalogTracker,
      commandTracker: commandTracker,
      stagedCommandTracker: stagedCommandTracker,
      totalTimeout: const Duration(seconds: 12),
      maxCandidates: 8,
    );
    final cursorSessionOptionsService = CursorSessionOptionsService(
      catalogService: catalogService,
      catalogTracker: catalogTracker,
      commandTracker: commandTracker,
      launchDirectory: cwd,
    );
    // The mapper needs the plugin's active-turn resolver and the plugin is
    // constructed with the mapper; `plugin` is assigned immediately below,
    // before any notification can invoke the closure.
    late final CursorPlugin plugin;
    final mapper = CursorEventMapper(
      launchDirectory: cwd,
      pluginId: pluginId,
      configurationTracker: configurationTracker,
      contentMapper: contentMapper,
      generatedImageReader: const CursorGeneratedImageReader(),
      activeSessionResolver: () => plugin.activeTurnSessionId,
    );
    return plugin = CursorPlugin._(
      launchSpec: launchSpec,
      launchDirectory: cwd,
      mapper: mapper,
      contentMapper: contentMapper,
      processFactory: processFactory,
      catalogService: catalogService,
      catalogCommandListener: catalogCommandListener,
      catalogTracker: catalogTracker,
      cursorSessionOptionsService: cursorSessionOptionsService,
      configurationTracker: configurationTracker,
      commandTracker: commandTracker,
      sessionOptionsService: acpSessionOptionsService,
      sessionCleanupService: sessionCleanupService,
    );
  }

  CursorPlugin._({
    required super.launchSpec,
    required super.launchDirectory,
    required super.contentMapper,
    required CursorEventMapper mapper,
    required CursorCatalogService catalogService,
    required AcpCommandListener catalogCommandListener,
    required CursorCatalogTracker catalogTracker,
    required CursorSessionOptionsService cursorSessionOptionsService,
    required AcpSessionConfigurationTracker configurationTracker,
    required super.commandTracker,
    required super.sessionOptionsService,
    required CursorSessionCleanupService sessionCleanupService,
    super.processFactory,
  }) : _catalogService = catalogService,
       _catalogCommandListener = catalogCommandListener,
       _catalogTracker = catalogTracker,
       _sessionOptionsService = cursorSessionOptionsService,
       _configurationTracker = configurationTracker,
       _sessionCleanupService = sessionCleanupService,
       super(
         id: pluginId,
         agentDisplayName: "Cursor",
         eventMapper: mapper,
       );

  final CursorCatalogService _catalogService;
  final AcpCommandListener _catalogCommandListener;
  final CursorCatalogTracker _catalogTracker;
  final CursorSessionOptionsService _sessionOptionsService;
  final AcpSessionConfigurationTracker _configurationTracker;
  final CursorSessionCleanupService _sessionCleanupService;

  String? _appliedModelId;
  String? _appliedModeId;
  String? _appliedThoughtLevelId;

  @override
  String? get authMethodId => "cursor_login";

  @override
  Map<String, dynamic>? get initializeCapabilityMeta => const {"parameterizedModelPicker": true};

  @override
  AcpApprovalRegistry buildApprovalRegistry(AcpStdioClient client) {
    return CursorApprovalRegistry(
      client: client,
      emit: emitActivityEvent,
      onFireAndForgetNotification: handleAgentNotification,
      activeSessionResolver: () => activeTurnSessionId,
    );
  }

  @override
  void captureSessionConfig(
    AcpNewSessionResult result, {
    String? sessionId,
    bool fromNewSession = false,
  }) {
    final capture = _catalogService.captureSessionConfig(
      result: result,
      fromNewSession: fromNewSession,
      thoughtLevelModelId: null,
      captureThoughtLevelDefault: fromNewSession,
    );
    _applyCaptureToEventMapper(capture: capture, sessionId: sessionId);
  }

  void _applyCaptureToEventMapper({
    required CursorCatalogCaptureResult capture,
    required String? sessionId,
  }) {
    _configurationTracker.setProcessDefaults(
      modelId: _catalogTracker.currentModelId,
      providerId: _providerId,
    );
    final loadedModelId = capture.loadedModelId;
    if (sessionId != null && loadedModelId != null) {
      _configurationTracker.setSessionOverride(
        sessionId: sessionId,
        modelId: loadedModelId,
        providerId: _providerId,
      );
    }
  }

  @override
  Future<void> applyTurnSelection({
    required AcpStdioClient client,
    required String sessionId,
    required ({String providerID, String modelID})? model,
    required PluginSessionVariant? variant,
    required String? agent,
  }) async {
    final requestedModel = model?.modelID;
    final useDefault = requestedModel == null || requestedModel.isEmpty;
    final targetModel = useDefault
        ? _configurationTracker.snapshotForSession(sessionId: sessionId).modelId
        : requestedModel;
    final modelConfigId = _catalogTracker.modelConfigId;
    if (targetModel != null &&
        targetModel.isNotEmpty &&
        modelConfigId != null &&
        _catalogTracker.hasModel(modelId: targetModel)) {
      var applied = true;
      if (targetModel != _appliedModelId) {
        applied = await _setConfig(
          client: client,
          sessionId: sessionId,
          configId: modelConfigId,
          value: targetModel,
        );
        if (applied) {
          _appliedModelId = targetModel;
          _appliedThoughtLevelId = null;
        }
      }
      if (applied) {
        _configurationTracker.setSessionOverride(
          sessionId: sessionId,
          modelId: targetModel,
          providerId: _providerId,
        );
      }
    }

    final requestedMode = _catalogTracker.resolveModeId(agent: agent) ?? _catalogTracker.defaultModeId;
    final modeConfigId = _catalogTracker.modeConfigId;
    if (requestedMode != null &&
        modeConfigId != null &&
        _catalogTracker.hasModeOption(modeId: requestedMode) &&
        requestedMode != _appliedModeId) {
      if (await _setConfig(
        client: client,
        sessionId: sessionId,
        configId: modeConfigId,
        value: requestedMode,
      )) {
        _appliedModeId = requestedMode;
      }
    }

    final thoughtLevelModelId =
        _configurationTracker.snapshotForSession(sessionId: sessionId).modelId ?? _catalogTracker.currentModelId ?? "";
    final thoughtLevel = _catalogTracker.thoughtLevelForModel(
      modelId: thoughtLevelModelId,
    );
    final requestedThoughtLevel = variant != null && variant.id.isNotEmpty ? variant.id : thoughtLevel?.defaultValue;
    if (requestedThoughtLevel != null &&
        thoughtLevel != null &&
        requestedThoughtLevel != _appliedThoughtLevelId &&
        thoughtLevel.variants.contains(requestedThoughtLevel)) {
      if (await _setConfig(
        client: client,
        sessionId: sessionId,
        configId: thoughtLevel.configId,
        value: requestedThoughtLevel,
      )) {
        _appliedThoughtLevelId = requestedThoughtLevel;
      }
    }
  }

  Future<bool> _setConfig({
    required AcpStdioClient client,
    required String sessionId,
    required String configId,
    required String value,
  }) async {
    try {
      final raw = await client.request(
        method: AcpMethods.sessionSetConfigOption,
        params: {
          "sessionId": sessionId,
          "configId": configId,
          "value": value,
        },
      );
      if (raw is Map) {
        final result = AcpNewSessionResult.fromJson(
          raw.cast<String, dynamic>(),
        );
        final capture = _catalogService.captureSessionConfig(
          result: result,
          fromNewSession: false,
          thoughtLevelModelId: configId == _catalogTracker.modelConfigId ? value : null,
          captureThoughtLevelDefault: configId == _catalogTracker.modelConfigId,
        );
        _applyCaptureToEventMapper(capture: capture, sessionId: sessionId);
      }
      return true;
    } catch (error, stack) {
      Log.w(
        "[cursor] set_config_option($configId=$value) rejected",
        error,
        stack,
      );
      return false;
    }
  }

  @override
  void onConnectionReset() {
    _appliedModelId = null;
    _appliedModeId = null;
    _appliedThoughtLevelId = null;
  }

  Future<void> warmCatalog() async {
    try {
      await _sessionOptionsService.warmCatalog();
    } on Object catch (error, stack) {
      Log.w(
        "[cursor] warmCatalog failed; will populate lazily",
        error,
        stack,
      );
    }
  }

  @override
  Future<List<PluginCommand>> getCommands({required String? projectId}) =>
      _sessionOptionsService.listCommands(projectId: projectId);

  @override
  Future<PluginSessionOptionsDiscoveryResult> getSessionOptions({
    required String projectId,
    required PluginSessionOptionsDiscoveryMode discoveryMode,
  }) => _sessionOptionsService.getSessionOptions(
    projectId: projectId,
    discoveryMode: discoveryMode,
  );

  @override
  String commandForDispatch({required String command}) => _sessionOptionsService.backendCommandFor(command: command);

  @override
  Future<List<PluginAgent>> getAgents({required String projectId}) async {
    return _sessionOptionsService.listAgents(projectId: projectId);
  }

  @override
  Future<void> deletePersistedSession({required String backendSessionId}) {
    return _sessionCleanupService.deletePersistedSession(
      backendSessionId: backendSessionId,
    );
  }

  @override
  Future<PluginProvidersResult> getProviders({required String projectId}) async {
    return _sessionOptionsService.listProviders(projectId: projectId);
  }

  @override
  Future<void> dispose() async {
    try {
      await _catalogCommandListener.dispose();
    } on Object catch (error, stack) {
      Log.w("[cursor] failed to dispose catalog command listener", error, stack);
    }
    try {
      await _catalogService.dispose();
    } on Object catch (error, stack) {
      Log.w("[cursor] failed to dispose catalog service", error, stack);
    }
    await super.dispose();
  }
}
