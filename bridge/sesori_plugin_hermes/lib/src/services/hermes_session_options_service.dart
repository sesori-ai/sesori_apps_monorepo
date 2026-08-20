import "package:acp_plugin/acp_plugin.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "../models/hermes_model_catalog.dart";
import "../repositories/hermes_catalog_repository.dart";

/// Owns Hermes's process-scoped model catalog and exact per-session writes.
class HermesSessionOptionsService({
  required final HermesCatalogRepository _repository,
  required final AcpSessionConfigurationTracker _configurationTracker,
  required final AcpCommandTracker _commandTracker,
  required final String _launchDirectory,
  required final String _pluginId,
  required final String _agentDisplayName,
  required final Duration _discoveryTimeout,
}) {
  HermesModelCatalog? _catalog;
  Future<HermesCatalogDiscoveryResult>? _inFlight;
  final Set<String> _sessionIds = {};
  int _catalogRevision = 0;
  bool _disposed = false;

  Future<PluginSessionOptionsDiscoveryResult> getSessionOptions({
    required PluginSessionOptionsDiscoveryMode discoveryMode,
  }) async {
    final discovery = switch (discoveryMode) {
      PluginSessionOptionsDiscoveryMode.reuse => await _ensureCatalog(),
      PluginSessionOptionsDiscoveryMode.refresh => await _refreshCatalog(),
    };
    return switch (discovery) {
      HermesCatalogObserved(:final catalog) => PluginSessionOptionsDiscoveryResult.observed(
        options: _options(catalog: catalog),
      ),
      HermesCatalogDiscoveryFailed() when _catalog != null => const PluginSessionOptionsDiscoveryResult.failed(),
      HermesCatalogDiscoveryFailed() when _configurationTracker.processDefaults.modelId != null =>
        PluginSessionOptionsDiscoveryResult.observed(options: _options(catalog: null)),
      HermesCatalogDiscoveryFailed() => const PluginSessionOptionsDiscoveryResult.failed(),
    };
  }

  Future<List<PluginAgent>> listAgents() async {
    final result = await _ensureCatalog();
    return _options(catalog: result is HermesCatalogObserved ? result.catalog : _catalog).agents;
  }

  Future<PluginProvidersResult> listProviders() async {
    final result = await _ensureCatalog();
    return _options(catalog: result is HermesCatalogObserved ? result.catalog : _catalog).providers;
  }

  void captureSessionConfig(
    AcpNewSessionResult result, {
    required String? sessionId,
    required bool fromNewSession,
  }) {
    final catalog = _repository.mapSessionResult(result: result);
    if (catalog == null) return;
    final current = catalog.currentModel;
    if (fromNewSession) {
      _catalog = catalog;
      _catalogRevision++;
      if (current != null) {
        _configurationTracker.setProcessDefaults(
          modelId: current.value,
          providerId: current.providerId,
        );
      }
    }
    if (sessionId != null && current != null) {
      _sessionIds.add(sessionId);
      _configurationTracker.setSessionOverride(
        sessionId: sessionId,
        modelId: current.value,
        providerId: current.providerId,
      );
    }
  }

  Future<void> applyTurnSelection({
    required AcpStdioClient liveClient,
    required String sessionId,
    required ({String providerID, String modelID})? model,
  }) async {
    if (model == null) return;
    final requested = model.modelID;
    final currentValue = _configurationTracker.snapshotForSession(sessionId: sessionId).modelId;
    if (requested == currentValue) return;
    try {
      await _repository.setModel(
        liveClient: liveClient,
        sessionId: sessionId,
        modelId: requested,
        timeout: const Duration(seconds: 30),
      );
    } on Object catch (error, stackTrace) {
      Error.throwWithStackTrace(
        PluginOperationException(
          "session/set_model",
          message: "Hermes rejected the requested model",
          cause: error,
        ),
        stackTrace,
      );
    }
    _sessionIds.add(sessionId);
    _configurationTracker.setSessionOverride(
      sessionId: sessionId,
      modelId: requested,
      providerId: model.providerID,
    );
  }

  void forgetSession({required String sessionId}) {
    _sessionIds.remove(sessionId);
    _configurationTracker.forgetSession(sessionId: sessionId);
  }

  void resetConnection() {
    for (final sessionId in _sessionIds) {
      _configurationTracker.forgetSession(sessionId: sessionId);
    }
    _sessionIds.clear();
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _inFlight;
    await _repository.dispose();
  }

  Future<HermesCatalogDiscoveryResult> _ensureCatalog() {
    final existing = _catalog;
    if (existing != null) return Future.value(HermesCatalogObserved(catalog: existing));
    return _coalescedProbe();
  }

  Future<HermesCatalogDiscoveryResult> _refreshCatalog() => _coalescedProbe();

  Future<HermesCatalogDiscoveryResult> _coalescedProbe() {
    final pending = _inFlight;
    if (pending != null) return pending;
    if (_disposed) return Future.value(const HermesCatalogDiscoveryFailed());
    late final Future<HermesCatalogDiscoveryResult> operation;
    operation = _probe(catalogRevision: _catalogRevision).whenComplete(() {
      if (identical(_inFlight, operation)) _inFlight = null;
    });
    _inFlight = operation;
    return operation;
  }

  Future<HermesCatalogDiscoveryResult> _probe({required int catalogRevision}) async {
    try {
      final catalog = await _repository.discoverCatalog(
        cwd: _launchDirectory,
        timeout: _discoveryTimeout,
      );
      if (catalogRevision != _catalogRevision) {
        final liveCatalog = _catalog;
        return liveCatalog == null ? const HermesCatalogDiscoveryFailed() : HermesCatalogObserved(catalog: liveCatalog);
      }
      _catalog = catalog;
      final current = catalog.currentModel;
      if (current != null) {
        _configurationTracker.setProcessDefaults(
          modelId: current.value,
          providerId: current.providerId,
        );
      }
      return HermesCatalogObserved(catalog: catalog);
    } on Object catch (error, stackTrace) {
      Log.w("[$_pluginId] model catalog discovery failed", error, stackTrace);
      return const HermesCatalogDiscoveryFailed();
    }
  }

  PluginSessionOptions _options({required HermesModelCatalog? catalog}) {
    final defaults = _configurationTracker.processDefaults;
    final fallbackModelId = defaults.modelId;
    final fallbackProviderId = defaults.providerId ?? _pluginId;
    final current = catalog?.currentModel;
    return PluginSessionOptions(
      agents: [
        PluginAgent(
          name: _pluginId,
          description: "$_agentDisplayName session",
          model: current != null
              ? PluginAgentModel(
                  modelID: current.value,
                  providerID: current.providerId,
                  variant: null,
                )
              : fallbackModelId == null
              ? null
              : PluginAgentModel(
                  modelID: fallbackModelId,
                  providerID: fallbackProviderId,
                  variant: null,
                ),
          mode: PluginAgentMode.primary,
          hidden: false,
        ),
      ],
      providers: PluginProvidersResult(
        providers: catalog == null
            ? _fallbackProviders(modelId: fallbackModelId, providerId: fallbackProviderId)
            : _providers(catalog),
      ),
      commands: _commandTracker.commands,
      completeness: catalog != null && _commandTracker.hasSnapshot
          ? PluginSessionOptionsCompleteness.complete
          : PluginSessionOptionsCompleteness.partial,
    );
  }

  List<PluginProvider> _providers(HermesModelCatalog catalog) {
    final modelsByProvider = <String, List<HermesCatalogModel>>{};
    final providerNames = <String, String>{};
    for (final model in catalog.models) {
      (modelsByProvider[model.providerId] ??= []).add(model);
      providerNames[model.providerId] = model.providerName;
    }
    final current = catalog.currentModel;
    final entries = modelsByProvider.entries.toList(growable: true);
    if (current != null) {
      final currentIndex = entries.indexWhere((entry) => entry.key == current.providerId);
      if (currentIndex > 0) entries.insert(0, entries.removeAt(currentIndex));
    }
    return [
      for (final entry in entries)
        PluginProvider.custom(
          id: entry.key,
          name: providerNames[entry.key] ?? entry.key,
          authType: PluginProviderAuthType.unknown,
          models: [
            for (final model in entry.value)
              PluginModel(
                id: model.value,
                name: model.name,
                variants: const [],
                family: null,
                isAvailable: true,
                releaseDate: null,
              ),
          ],
          defaultModelID: current?.providerId == entry.key ? current?.value : null,
        ),
    ];
  }

  List<PluginProvider> _fallbackProviders({
    required String? modelId,
    required String providerId,
  }) => modelId == null
      ? const []
      : [
          PluginProvider.custom(
            id: providerId,
            name: _agentDisplayName,
            authType: PluginProviderAuthType.unknown,
            models: [
              PluginModel(
                id: modelId,
                name: modelId,
                variants: const [],
                family: null,
                isAvailable: true,
                releaseDate: null,
              ),
            ],
            defaultModelID: modelId,
          ),
        ];
}
