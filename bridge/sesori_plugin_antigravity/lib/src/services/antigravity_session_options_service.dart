import "package:acp_plugin/acp_plugin.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "../foundation/antigravity_identity.dart";
import "../models/antigravity_model_catalog.dart";
import "../repositories/mappers/antigravity_protocol_mapper.dart";
import "../trackers/antigravity_catalog_tracker.dart";

class AntigravitySessionOptionsService({
  required final AntigravityProtocolMapper _protocolMapper,
  required final AntigravityCatalogTracker _catalogTracker,
  required final AcpSessionConfigurationTracker _configurationTracker,
}) {
  /// Called only with real new/load/resume or configuration responses, never a scratch session.
  void capture({
    required AcpNewSessionResult result,
    required String sessionId,
    required AntigravityCatalogSource source,
  }) {
    final catalog = _validatedCatalog(result: result);
    if (catalog == null) return;
    _store(catalog: catalog, source: source);
    if (source == AntigravityCatalogSource.newSession) {
      _configurationTracker.setProcessDefaults(
        modelId: catalog.currentModelId,
        providerId: AntigravityIdentity.pluginId,
      );
    }
    _configurationTracker.setSessionOverride(
      sessionId: sessionId,
      modelId: catalog.currentModelId,
      providerId: AntigravityIdentity.pluginId,
    );
  }

  AntigravityModelCatalog? _validatedCatalog({required AcpNewSessionResult result}) {
    final catalog = _protocolMapper.mapModelCatalog(result: result);
    if (catalog == null) return null;
    final ids = <String>{};
    for (final model in catalog.models) {
      if (model.id.trim().isEmpty || model.name.trim().isEmpty || !ids.add(model.id)) {
        throw const FormatException("Antigravity model catalog has empty labels/IDs or duplicate IDs");
      }
    }
    if (ids.isEmpty || !ids.contains(catalog.currentModelId)) {
      throw const FormatException("Antigravity model catalog has no selectable current model");
    }
    return catalog;
  }

  void _store({required AntigravityModelCatalog catalog, required AntigravityCatalogSource source}) {
    final defaultId = source == AntigravityCatalogSource.newSession
        ? catalog.currentModelId
        : _catalogTracker.newSessionDefaultModelId;
    _catalogTracker.storeValidated(
      catalog: catalog,
      newSessionDefaultModelId: catalog.models.any((model) => model.id == defaultId) ? defaultId : null,
    );
  }

  void resetConnection() {
    _catalogTracker.clear();
    _configurationTracker.clear();
  }

  PluginSessionOptions getSessionOptions() {
    final catalog = _catalogTracker.snapshot;
    return PluginSessionOptions(
      agents: const [
        PluginAgent(
          name: AntigravityIdentity.pluginId,
          description: "Antigravity session",
          model: null,
          mode: PluginAgentMode.primary,
          hidden: false,
        ),
      ],
      providers: PluginProvidersResult(
        providers: catalog == null
            ? const []
            : [
                PluginProvider(
                  id: AntigravityIdentity.pluginId,
                  name: AntigravityIdentity.displayName,
                  authType: PluginProviderAuthType.oauth,
                  models: CatalogStrengthOrder.models(
                    [
                      for (final model in catalog.models)
                        PluginModel(
                          id: model.id,
                          name: model.name,
                          variants: const [],
                          family: null,
                          isAvailable: true,
                          releaseDate: null,
                        ),
                    ],
                    idOf: (model) => model.id,
                  ),
                  defaultModelID: _catalogTracker.newSessionDefaultModelId,
                ),
              ],
      ),
      commands: const [],
      completeness: catalog == null
          ? PluginSessionOptionsCompleteness.partial
          : PluginSessionOptionsCompleteness.complete,
    );
  }

  void validateSelection({
    required String operation,
    required String? providerId,
    required String? modelId,
    required PluginSessionVariant? variant,
    required String? agent,
  }) {
    if ((providerId != null && providerId != AntigravityIdentity.pluginId) ||
        (agent != null && agent != AntigravityIdentity.pluginId) ||
        variant != null) {
      throw PluginStaleOptionsException(
        operation,
        message: "Antigravity supports its primary agent and advertised models only",
      );
    }
    // After reset, residency must restore the catalog before dispatch validates it.
    if (modelId != null && _catalogTracker.snapshot != null) {
      _validateModel(operation: operation, modelId: modelId);
    }
  }

  /// Await before dispatching a prompt. A null model preserves the account/session default.
  Future<void> applyForPrompt({
    required AcpSessionConfigRepository configRepository,
    required String sessionId,
    required String? modelId,
  }) async {
    if (modelId != null) {
      final catalog = _validateModel(operation: "session/prompt", modelId: modelId);
      final result = await configRepository.setConfigOption(
        sessionId: sessionId,
        configId: catalog.configId,
        value: modelId,
      );
      if (result != null) {
        final updated = _validatedCatalog(result: result);
        if (updated != null) {
          if (updated.currentModelId != modelId) {
            throw StateError("Antigravity did not apply the requested model selection");
          }
          _store(catalog: updated, source: AntigravityCatalogSource.existingSession);
        }
      }
      _configurationTracker.setSessionOverride(
        sessionId: sessionId,
        modelId: modelId,
        providerId: AntigravityIdentity.pluginId,
      );
    }
    await configRepository.setMode(sessionId: sessionId, modeId: AntigravitySessionMode.defaultMode.id);
  }

  AntigravityModelCatalog _validateModel({required String operation, required String modelId}) {
    final catalog = _catalogTracker.snapshot;
    if (catalog == null || !catalog.models.any((model) => model.id == modelId)) {
      final diagnosticId = modelId.length <= 120 ? modelId : "${modelId.substring(0, 120)}…";
      throw PluginStaleOptionsException(
        operation,
        message: "Antigravity model '$diagnosticId' is not in the current account catalog",
      );
    }
    return catalog;
  }
}
