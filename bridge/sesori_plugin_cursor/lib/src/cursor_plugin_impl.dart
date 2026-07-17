import "dart:io" show Directory;

import "package:acp_plugin/acp_plugin.dart";
import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart" show normalizeProjectDirectory;
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "api/cursor_catalog_api.dart";
import "cursor_approval_registry.dart";
import "cursor_binary.dart";
import "cursor_event_mapper.dart";
import "dispatchers/cursor_turn_configuration_dispatcher.dart";
import "repositories/cursor_catalog_repository.dart";
import "services/cursor_catalog_service.dart";
import "trackers/cursor_catalog_tracker.dart";

/// Cursor backend over ACP plus Cursor's config-option model picker.
class CursorPlugin extends AcpPlugin {
  static const String pluginId = "cursor";
  static const String _providerId = "cursor";

  @override
  bool get supportsIdentityPreservingRowlessChildSessions => false;

  factory CursorPlugin({
    String binaryPath = CursorBinary.defaultBinary,
    String? launchDirectory,
    String? apiEndpoint,
    AcpProcessFactory? processFactory,
  }) {
    final cwd = launchDirectory ?? Directory.current.path;
    final launchSpec = CursorBinary.launchSpec(
      binary: binaryPath,
      cwd: cwd,
      apiEndpoint: apiEndpoint,
    );
    final clientBuilder = AcpStdioClientBuilder(
      launchSpec: launchSpec,
      processFactory: processFactory,
    );
    final catalogRepository = CursorCatalogRepository(
      api: CursorCatalogApi(
        client: clientBuilder.build(logTag: "$pluginId-catalog"),
      ),
      launchScope: cwd,
    );
    final catalogTracker = CursorCatalogTracker();
    final catalogService = CursorCatalogService(
      repository: catalogRepository,
      tracker: catalogTracker,
      totalTimeout: const Duration(seconds: 12),
      maxCandidates: 8,
    );
    final mapper = CursorEventMapper(launchDirectory: cwd, pluginId: pluginId);
    final turnConfigurationDispatcher = CursorTurnConfigurationDispatcher(
      catalogService: catalogService,
      catalogTracker: catalogTracker,
      eventMapper: mapper,
      providerId: _providerId,
    );
    final liveClient = clientBuilder.build(logTag: pluginId);
    final api = AcpApi(client: liveClient);
    final sessionRepository = AcpSessionRepository(api: api);
    final commandTracker = AcpCommandTracker();
    final commandTurnTracker = AcpCommandTurnTracker();
    final directoryTracker = AcpSessionDirectoryTracker(launchDirectory: cwd);
    final residencyTracker = AcpSessionResidencyTracker();
    final queueTracker = AcpTurnQueueTracker(pluginId: pluginId);
    final eventDispatcher = AcpTurnEventDispatcher(
      eventMapper: mapper,
      commandTracker: commandTracker,
      commandTurnTracker: commandTurnTracker,
      residencyTracker: residencyTracker,
    );
    final connectionService = AcpConnectionService(
      client: liveClient,
      repository: sessionRepository,
      configuration: const AcpConnectionConfiguration(
        initializeRequest: AcpInitializeRequest(
          clientName: "sesori-bridge",
          clientVersion: "0.0.0",
          clientTitle: null,
          capabilityMeta: {"parameterizedModelPicker": true},
        ),
        authMethodId: "cursor_login",
      ),
    );
    final notificationListener = AcpNotificationListener(
      notificationRepository: AcpNotificationRepository(
        apiNotifications: api.notifications,
      ),
      eventDispatcher: eventDispatcher,
    );
    final approvalRegistry = CursorApprovalRegistry(
      client: liveClient,
      emit: eventDispatcher.emit,
      activeSessionResolver: queueTracker.resolveActiveSession,
    );
    final approvalListener = AcpApprovalListener(
      registry: approvalRegistry,
      requests: liveClient.serverRequests,
    );
    final turnService = AcpTurnService(
      pluginId: pluginId,
      connectionService: connectionService,
      directoryTracker: directoryTracker,
      residencyTracker: residencyTracker,
      queueTracker: queueTracker,
      commandTurnTracker: commandTurnTracker,
      eventDispatcher: eventDispatcher,
      turnConfigurationDispatcher: turnConfigurationDispatcher,
      commandFastFailWindow: const Duration(milliseconds: 100),
    );
    return CursorPlugin._(
      launchSpec: launchSpec,
      launchDirectory: cwd,
      mapper: mapper,
      clientBuilder: clientBuilder,
      commandTracker: commandTracker,
      connectionService: connectionService,
      notificationListener: notificationListener,
      approvalListener: approvalListener,
      approvalRegistry: approvalRegistry,
      directoryTracker: directoryTracker,
      turnService: turnService,
      catalogService: catalogService,
      catalogTracker: catalogTracker,
      turnConfigurationDispatcher: turnConfigurationDispatcher,
    );
  }

  CursorPlugin._({
    required super.launchSpec,
    required super.launchDirectory,
    required CursorEventMapper mapper,
    required CursorCatalogService catalogService,
    required CursorCatalogTracker catalogTracker,
    required CursorTurnConfigurationDispatcher turnConfigurationDispatcher,
    required super.clientBuilder,
    required super.commandTracker,
    required super.connectionService,
    required super.notificationListener,
    required super.approvalListener,
    required super.approvalRegistry,
    required super.directoryTracker,
    required super.turnService,
  }) : _catalogService = catalogService,
       _catalogTracker = catalogTracker,
       super.configured(
         id: pluginId,
         agentDisplayName: "Cursor",
         eventMapper: mapper,
         turnConfigurationDispatcher: turnConfigurationDispatcher,
       );

  final CursorCatalogService _catalogService;
  final CursorCatalogTracker _catalogTracker;

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
      await _catalogService.dispose();
    } on Object catch (error, stack) {
      Log.w("[cursor] failed to dispose catalog service", error, stack);
    }
    await super.dispose();
  }
}
