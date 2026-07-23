import "dart:io" show Directory;

import "package:acp_plugin/acp_plugin.dart";
import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart" show normalizeProjectDirectory;
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "api/cursor_catalog_probe_api.dart";
import "cursor_approval_registry.dart";
import "cursor_binary.dart";
import "cursor_event_mapper.dart";
import "models/cursor_catalog_models.dart";
import "repositories/cursor_catalog_repository.dart";
import "services/cursor_catalog_service.dart";
import "services/cursor_command_service.dart";
import "services/cursor_session_cleanup_service.dart";
import "trackers/cursor_catalog_tracker.dart";

/// Cursor backend over ACP plus Cursor's config-option model picker.
class CursorPlugin extends AcpPlugin implements PersistedSessionCleanupApi {
  static const String pluginId = "cursor";
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
    final catalogCommandListener = AcpCommandListener(
      notifications: catalogApi.notifications,
      tracker: commandTracker,
    );
    final catalogService = CursorCatalogService(
      repository: catalogRepository,
      tracker: catalogTracker,
      totalTimeout: const Duration(seconds: 12),
      maxCandidates: 8,
    );
    final commandService = CursorCommandService(
      catalogService: catalogService,
      commandTracker: commandTracker,
      launchDirectory: cwd,
    );
    return CursorPlugin._(
      launchSpec: launchSpec,
      launchDirectory: cwd,
      mapper: CursorEventMapper(launchDirectory: cwd, pluginId: pluginId),
      processFactory: processFactory,
      catalogService: catalogService,
      catalogCommandListener: catalogCommandListener,
      catalogTracker: catalogTracker,
      commandService: commandService,
      commandTracker: commandTracker,
      sessionCleanupService: sessionCleanupService,
    );
  }

  CursorPlugin._({
    required super.launchSpec,
    required super.launchDirectory,
    required CursorEventMapper mapper,
    required CursorCatalogService catalogService,
    required AcpCommandListener catalogCommandListener,
    required CursorCatalogTracker catalogTracker,
    required CursorCommandService commandService,
    required super.commandTracker,
    required CursorSessionCleanupService sessionCleanupService,
    super.processFactory,
  }) : _catalogService = catalogService,
       _catalogCommandListener = catalogCommandListener,
       _catalogTracker = catalogTracker,
       _commandService = commandService,
       _sessionCleanupService = sessionCleanupService,
       super(
         id: pluginId,
         agentDisplayName: "Cursor",
         eventMapper: mapper,
       );

  final CursorCatalogService _catalogService;
  final AcpCommandListener _catalogCommandListener;
  final CursorCatalogTracker _catalogTracker;
  final CursorCommandService _commandService;
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
    eventMapper.currentProviderId = _providerId;
    eventMapper.currentModelId = _catalogTracker.currentModelId;
    final loadedModelId = capture.loadedModelId;
    if (sessionId != null && loadedModelId != null) {
      eventMapper.setSessionModel(
        sessionId,
        loadedModelId,
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
    final targetModel = useDefault ? eventMapper.modelForSession(sessionId) : requestedModel;
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
        eventMapper.setSessionModel(
          sessionId,
          targetModel,
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

    final thoughtLevelModelId = eventMapper.modelForSession(sessionId) ?? _catalogTracker.currentModelId ?? "";
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

  Future<void> _ensureCatalog({required String projectId}) {
    return _catalogService.ensureCatalog(
      scope: normalizeProjectDirectory(directory: projectId),
    );
  }

  Future<void> warmCatalog() async {
    try {
      await _ensureCatalog(projectId: launchDirectory);
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
      _commandService.listCommands(projectId: projectId);

  @override
  Future<void> sendCommand({
    required String sessionId,
    required String command,
    required String arguments,
    required PluginSessionVariant? variant,
    required String? agent,
    required ({String providerID, String modelID})? model,
  }) => super.sendCommand(
    sessionId: sessionId,
    command: _commandService.backendCommandFor(command: command),
    arguments: arguments,
    variant: variant,
    agent: agent,
    model: model,
  );

  List<PluginAgent> _modeAgents() {
    final modes = _catalogTracker.modes;
    if (modes.isEmpty) {
      return [
        const PluginAgent(
          name: "Cursor",
          description: "Cursor CLI session",
          model: null,
          mode: PluginAgentMode.primary,
          hidden: false,
        ),
      ];
    }

    final ordered = modes.toList(growable: true);
    final defaultMode = _catalogTracker.defaultModeId;
    if (defaultMode != null) {
      final defaultIndex = ordered.indexWhere(
        (mode) => mode.value == defaultMode,
      );
      if (defaultIndex > 0) {
        ordered.insert(0, ordered.removeAt(defaultIndex));
      }
    }
    return [
      for (final mode in ordered)
        PluginAgent(
          name: mode.name,
          description: mode.description,
          model: null,
          mode: PluginAgentMode.primary,
          hidden: false,
        ),
    ];
  }

  @override
  Future<List<PluginAgent>> getAgents({required String projectId}) async {
    await _ensureCatalog(projectId: projectId);
    return _modeAgents();
  }

  @override
  Future<void> deletePersistedSession({required String backendSessionId}) {
    return _sessionCleanupService.deletePersistedSession(
      backendSessionId: backendSessionId,
    );
  }

  @override
  Future<PluginProvidersResult> getProviders({required String projectId}) async {
    await _ensureCatalog(projectId: projectId);
    final models = _catalogTracker.models;
    if (models.isEmpty) return const PluginProvidersResult(providers: []);
    return PluginProvidersResult(
      providers: [
        PluginProvider.custom(
          id: _providerId,
          name: "Cursor",
          authType: PluginProviderAuthType.unknown,
          models: [
            for (final model in models)
              PluginModel(
                id: model.value,
                name: model.name,
                variants: _catalogTracker.variantsForModel(modelId: model.value),
                family: null,
                isAvailable: true,
                releaseDate: null,
              ),
          ],
          defaultModelID: _catalogTracker.currentModelId ?? _catalogTracker.firstModelId,
        ),
      ],
    );
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
