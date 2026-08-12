import "package:acp_plugin/acp_plugin.dart"
    show AcpNewSessionResult, AcpSessionConfigRepository, AcpSessionConfigurationTracker;
import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart" show normalizeProjectDirectory;
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "../models/omp_catalog_models.dart";
import "../repositories/omp_catalog_repository.dart";
import "../trackers/omp_catalog_tracker.dart";
import "omp_catalog_service.dart";

/// Owns OMP's project-scoped options and exact turn-selection writes.
class OmpSessionOptionsService({
    required OmpCatalogService catalogService,
    required OmpCatalogTracker tracker,
    required OmpCatalogRepository repository,
    required AcpSessionConfigurationTracker configurationTracker,
    required String launchDirectory,
  }) {
  this : _catalogService = catalogService,
       _tracker = tracker,
       _repository = repository,
       _configurationTracker = configurationTracker,
       _launchDirectory = normalizeProjectDirectory(directory: launchDirectory);

  final OmpCatalogService _catalogService;
  final OmpCatalogTracker _tracker;
  final OmpCatalogRepository _repository;
  final AcpSessionConfigurationTracker _configurationTracker;
  final String _launchDirectory;
  final Map<String, OmpSessionConfigSnapshot> _sessionConfigs = {};

  void captureSessionConfig(
    AcpNewSessionResult result, {
    required String? sessionId,
    required bool fromNewSession,
  }) {
    final snapshot = _repository.mapSessionResult(result: result);
    if (sessionId != null) _sessionConfigs[sessionId] = snapshot;
    final modelValue = snapshot.currentModelValue;
    if (fromNewSession) {
      _configurationTracker.setProcessDefaults(
        modelId: modelValue,
        providerId: modelValue == null ? null : _providerId(modelValue),
      );
    }
    if (sessionId != null && modelValue != null) {
      _setSessionConfiguration(sessionId: sessionId, modelValue: modelValue);
    }
  }

  Future<OmpOptionsDiscoveryResult> getSessionOptions({
    required String projectId,
    required PluginSessionOptionsDiscoveryMode discoveryMode,
  }) async {
    final scope = _scope(projectId);
    final result = switch (discoveryMode) {
      PluginSessionOptionsDiscoveryMode.reuse => await _catalogService.ensureCatalog(projectId: scope),
      PluginSessionOptionsDiscoveryMode.refresh => await _catalogService.refreshCatalog(projectId: scope),
    };
    return switch (result) {
      OmpCatalogObserved(:final catalog) => OmpOptionsObserved(options: _options(catalog)),
      OmpCatalogNoModels() => const OmpOptionsNoModels(),
      OmpCatalogDiscoveryFailed() => const OmpOptionsDiscoveryFailed(),
    };
  }

  Future<List<PluginCommand>> listCommands({required String? projectId}) async {
    final result = await _catalogService.ensureCatalog(projectId: _scope(projectId));
    return result is OmpCatalogObserved ? result.catalog.commands : const [];
  }

  Future<List<PluginAgent>> listAgents({required String projectId}) async {
    final result = await _catalogService.ensureCatalog(projectId: _scope(projectId));
    return result is OmpCatalogObserved ? _agents(result.catalog) : const [];
  }

  Future<PluginProvidersResult> listProviders({required String projectId}) async {
    final result = await _catalogService.ensureCatalog(projectId: _scope(projectId));
    return PluginProvidersResult(
      providers: result is OmpCatalogObserved ? _providers(result.catalog) : const [],
    );
  }

  Future<OmpSessionConfigSnapshot?> applyTurnSelection({
    required AcpSessionConfigRepository configRepository,
    required String sessionId,
    required String projectId,
    required ({String providerID, String modelID})? model,
    required PluginSessionVariant? variant,
    required String? agent,
  }) async {
    if (model == null && variant == null && (agent == null || agent.isEmpty)) {
      return _sessionConfigs[sessionId];
    }
    final catalog = _tracker.snapshotFor(projectId: projectId);
    var current = _sessionConfigs[sessionId];
    final requestedModel = model?.modelID;
    if (requestedModel != null && requestedModel.isNotEmpty) {
      final configId = current?.modelConfigId ?? catalog?.modelConfigId;
      final models = current?.models.isNotEmpty ?? false ? current!.models : catalog?.models ?? const [];
      if (configId == null || !models.any((entry) => entry.value == requestedModel)) {
        throw const PluginOperationException(
          "session/set_config_option",
          message: "Requested OMP model is unavailable",
        );
      }
      current = await _writeAndVerify(
        configRepository: configRepository,
        sessionId: sessionId,
        configId: configId,
        value: requestedModel,
      );
    }

    if (agent != null && agent.isNotEmpty) {
      final mode = _resolveMode(agent: agent, snapshot: current, catalog: catalog);
      final configId = current?.modeConfigId ?? catalog?.modeConfigId;
      if (mode == null || configId == null) {
        throw const PluginOperationException(
          "session/set_config_option",
          message: "Requested OMP mode is unavailable",
        );
      }
      current = await _writeAndVerify(
        configRepository: configRepository,
        sessionId: sessionId,
        configId: configId,
        value: mode,
      );
    }

    final requestedVariant = variant?.id;
    if (requestedVariant != null && requestedVariant.isNotEmpty) {
      final selectedModel = current?.currentModelValue ?? requestedModel;
      final thinking = current?.thinking ?? (selectedModel == null ? null : catalog?.thinkingByModel[selectedModel]);
      if (thinking == null || !thinking.variants.contains(requestedVariant)) {
        throw const PluginOperationException(
          "session/set_config_option",
          message: "Requested OMP thinking level is unavailable",
        );
      }
      current = await _writeAndVerify(
        configRepository: configRepository,
        sessionId: sessionId,
        configId: thinking.configId,
        value: requestedVariant,
      );
    }
    if (current != null) {
      _sessionConfigs[sessionId] = current;
      final modelValue = current.currentModelValue;
      if (modelValue != null) {
        _setSessionConfiguration(sessionId: sessionId, modelValue: modelValue);
      }
    }
    return current;
  }

  void forgetSession({required String sessionId}) => _sessionConfigs.remove(sessionId);

  void resetConnection() {
    _sessionConfigs.clear();
    _configurationTracker.clear();
  }

  Future<OmpSessionConfigSnapshot> _writeAndVerify({
    required AcpSessionConfigRepository configRepository,
    required String sessionId,
    required String configId,
    required String value,
  }) async {
    try {
      final result = await configRepository.setConfigOption(
        sessionId: sessionId,
        configId: configId,
        value: value,
      );
      if (result == null) throw StateError("OMP returned no config state");
      final snapshot = _repository.mapSessionResult(result: result);
      final applied = switch (configId) {
        final id when id == snapshot.modelConfigId => snapshot.currentModelValue,
        final id when id == snapshot.modeConfigId => snapshot.currentModeValue,
        final id when id == snapshot.thinking?.configId => snapshot.thinking?.currentValue,
        _ => null,
      };
      if (applied != value) throw StateError("OMP returned a different config value");
      return snapshot;
    } on Object catch (error, stack) {
      Error.throwWithStackTrace(
        PluginOperationException(
          "session/set_config_option",
          message: "OMP rejected the requested session option",
          cause: error,
        ),
        stack,
      );
    }
  }

  PluginSessionOptions _options(OmpProjectCatalog catalog) => PluginSessionOptions(
    agents: _agents(catalog),
    providers: PluginProvidersResult(providers: _providers(catalog)),
    commands: catalog.commands,
    completeness: catalog.completeness,
  );

  List<PluginAgent> _agents(OmpProjectCatalog catalog) {
    final modes = catalog.modes.toList(growable: true);
    final defaultMode = catalog.defaultModeValue;
    if (defaultMode != null) {
      final index = modes.indexWhere((mode) => mode.value == defaultMode);
      if (index > 0) modes.insert(0, modes.removeAt(index));
    }
    return [
      for (final mode in modes)
        PluginAgent(
          name: mode.name,
          description: mode.description,
          model: null,
          mode: PluginAgentMode.primary,
          hidden: false,
        ),
    ];
  }

  List<PluginProvider> _providers(OmpProjectCatalog catalog) {
    final modelsByProvider = <String, List<OmpCatalogModel>>{};
    for (final model in catalog.models) {
      (modelsByProvider[model.providerId] ??= []).add(model);
    }
    final defaultProvider = catalog.models
        .where((model) => model.value == catalog.defaultModelValue)
        .firstOrNull
        ?.providerId;
    final providers = modelsByProvider.entries.toList(growable: true);
    if (defaultProvider != null) {
      final index = providers.indexWhere((entry) => entry.key == defaultProvider);
      if (index > 0) providers.insert(0, providers.removeAt(index));
    }
    return [
      for (final entry in providers)
        PluginProvider.custom(
          id: entry.key,
          name: entry.key,
          authType: PluginProviderAuthType.unknown,
          models: [
            for (final model in entry.value)
              PluginModel(
                id: model.value,
                name: model.name,
                variants: catalog.thinkingByModel[model.value]?.variants ?? const [],
                family: null,
                isAvailable: true,
                releaseDate: null,
              ),
          ],
          defaultModelID: entry.key == defaultProvider ? catalog.defaultModelValue : entry.value.first.value,
        ),
    ];
  }

  String? _resolveMode({
    required String agent,
    required OmpSessionConfigSnapshot? snapshot,
    required OmpProjectCatalog? catalog,
  }) {
    final modes = snapshot?.modes.isNotEmpty ?? false ? snapshot!.modes : catalog?.modes ?? const [];
    for (final mode in modes) {
      if (mode.value == agent || mode.name == agent) return mode.value;
    }
    return null;
  }

  String _scope(String? projectId) {
    final trimmed = projectId?.trim();
    return trimmed == null || trimmed.isEmpty ? _launchDirectory : normalizeProjectDirectory(directory: trimmed);
  }

  void _setSessionConfiguration({required String sessionId, required String modelValue}) {
    _configurationTracker.setSessionOverride(
      sessionId: sessionId,
      modelId: modelValue,
      providerId: _providerId(modelValue),
    );
  }

  static String _providerId(String modelValue) {
    final separator = modelValue.indexOf("/");
    return separator > 0 ? modelValue.substring(0, separator) : "omp";
  }
}
