import "package:acp_plugin/acp_plugin.dart"
    show AcpCommandTracker, AcpInitializeResult, AcpNewSessionResult, AcpSessionConfigurationTracker, AcpStdioClient;
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "../api/grok_acp_api.dart";
import "../models/grok_model_catalog.dart";
import "../repositories/grok_catalog_repository.dart";
import "../repositories/grok_session_config_repository.dart";
import "../trackers/grok_catalog_tracker.dart";

/// Coordinates Grok catalog discovery, presentation, and exact turn selection.
class GrokSessionOptionsService({
  required final GrokCatalogRepository _catalogRepository,
  required final GrokSessionConfigRepository _configRepository,
  required final GrokCatalogTracker _catalogTracker,
  required final AcpSessionConfigurationTracker _configurationTracker,
  required final AcpCommandTracker _commandTracker,
  required final String _launchDirectory,
  required final String _pluginId,
  required final String _displayName,
  required final Duration _discoveryTimeout,
}) {
  static const Duration _selectionTimeout = Duration(seconds: 30);

  Future<PluginSessionOptionsDiscoveryResult> getSessionOptions({
    required PluginSessionOptionsDiscoveryMode discoveryMode,
  }) async {
    if (discoveryMode == PluginSessionOptionsDiscoveryMode.reuse && _catalogTracker.snapshot != null) {
      return PluginSessionOptionsDiscoveryResult.observed(options: _options());
    }
    try {
      final catalog = await _catalogRepository.discoverCatalog(
        cwd: _launchDirectory,
        timeout: _discoveryTimeout,
      );
      _replaceCatalog(catalog: catalog, updateProcessDefaults: true);
      return PluginSessionOptionsDiscoveryResult.observed(options: _options());
    } on Object catch (error, stackTrace) {
      Log.w("[$_pluginId] model catalog discovery failed", error, stackTrace);
      return const PluginSessionOptionsDiscoveryResult.failed();
    }
  }

  Future<List<PluginAgent>> listAgents() async {
    await _ensureCatalog();
    return _options().agents;
  }

  Future<PluginProvidersResult> listProviders() async {
    await _ensureCatalog();
    return _options().providers;
  }

  void captureInitializeResult({required AcpInitializeResult result}) {
    _replaceCatalog(
      catalog: _catalogRepository.mapInitializeResult(result: result),
      updateProcessDefaults: true,
    );
  }

  void captureSessionConfig({
    required AcpNewSessionResult result,
    required String? sessionId,
    required bool fromNewSession,
  }) {
    final catalog = _catalogRepository.mapSessionResult(result: result);
    if (catalog == null) return;
    _replaceCatalog(catalog: catalog, updateProcessDefaults: fromNewSession);
    if (sessionId != null) {
      _configurationTracker.setSessionOverride(
        sessionId: sessionId,
        modelId: catalog.currentModel?.id,
        providerId: catalog.currentModel == null ? null : _pluginId,
      );
    }
  }

  Future<void> applyTurnSelection({
    required AcpStdioClient liveClient,
    required String sessionId,
    required ({String providerID, String modelID})? model,
    required PluginSessionVariant? variant,
  }) async {
    if (model == null && variant == null) return;
    if (model != null && model.providerID != _pluginId) {
      throw const PluginOperationException(
        GrokAcpApi.sessionSetModelMethod,
        message: "Requested Grok provider is unavailable",
      );
    }
    final catalog = _catalogTracker.snapshot;
    final current = _configurationTracker.snapshotForSession(sessionId: sessionId);
    final modelId = model?.modelID ?? current.modelId ?? catalog?.currentModel?.id;
    final catalogModel = modelId == null ? null : catalog?.modelById(id: modelId);
    if (catalogModel == null) {
      throw const PluginOperationException(
        GrokAcpApi.sessionSetModelMethod,
        message: "Requested Grok model is unavailable",
      );
    }
    final reasoningEffort = variant?.id;
    if (reasoningEffort != null && !catalogModel.reasoningEfforts.contains(reasoningEffort)) {
      throw const PluginOperationException(
        GrokAcpApi.sessionSetModelMethod,
        message: "Requested Grok reasoning effort is unavailable",
      );
    }
    final selectedModelId = catalogModel.id;
    if (selectedModelId == current.modelId && reasoningEffort == null) return;

    await _configRepository.setSelection(
      liveClient: liveClient,
      sessionId: sessionId,
      modelId: selectedModelId,
      reasoningEffort: reasoningEffort,
      timeout: _selectionTimeout,
    );
    _configurationTracker.setSessionOverride(
      sessionId: sessionId,
      modelId: selectedModelId,
      providerId: _pluginId,
    );
  }

  void forgetSession({required String sessionId}) => _configurationTracker.forgetSession(sessionId: sessionId);

  void resetConnection() => _configurationTracker.clear();

  Future<void> _ensureCatalog() async {
    if (_catalogTracker.snapshot != null) return;
    await getSessionOptions(discoveryMode: PluginSessionOptionsDiscoveryMode.reuse);
  }

  void _replaceCatalog({
    required GrokModelCatalog catalog,
    required bool updateProcessDefaults,
  }) {
    _catalogTracker.replaceCatalog(catalog: catalog);
    if (!updateProcessDefaults) return;
    final current = catalog.currentModel;
    _configurationTracker.setProcessDefaults(
      modelId: current?.id,
      providerId: current == null ? null : _pluginId,
    );
  }

  PluginSessionOptions _options() {
    final catalog = _catalogTracker.snapshot;
    final configuredModelId = _configurationTracker.processDefaults.modelId;
    final selected = configuredModelId == null ? null : catalog?.modelById(id: configuredModelId);
    final defaultModel = selected ?? catalog?.defaultModel;
    return PluginSessionOptions(
      agents: [
        PluginAgent(
          name: _pluginId,
          description: "$_displayName session",
          model: defaultModel == null
              ? null
              : PluginAgentModel(
                  modelID: defaultModel.id,
                  providerID: _pluginId,
                  variant: defaultModel.currentReasoningEffort,
                ),
          mode: PluginAgentMode.primary,
          hidden: false,
        ),
      ],
      providers: PluginProvidersResult(
        providers: catalog == null || catalog.models.isEmpty
            ? const []
            : [
                PluginProvider(
                  id: _pluginId,
                  name: _displayName,
                  authType: PluginProviderAuthType.unknown,
                  models: [
                    for (final model in catalog.models)
                      PluginModel(
                        id: model.id,
                        name: model.name,
                        variants: model.reasoningEfforts,
                        family: null,
                        isAvailable: true,
                        releaseDate: null,
                      ),
                  ],
                  defaultModelID: defaultModel?.id,
                ),
              ],
      ),
      commands: _commandTracker.commands,
      completeness: catalog != null && _commandTracker.hasSnapshot
          ? PluginSessionOptionsCompleteness.complete
          : PluginSessionOptionsCompleteness.partial,
    );
  }
}
