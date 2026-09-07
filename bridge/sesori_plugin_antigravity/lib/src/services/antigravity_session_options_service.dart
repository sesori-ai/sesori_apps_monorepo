import "package:acp_plugin/acp_plugin.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "../foundation/antigravity_identity.dart";
import "../models/antigravity_model_catalog.dart";
import "../repositories/mappers/antigravity_protocol_mapper.dart";
import "../trackers/antigravity_catalog_tracker.dart";

class AntigravitySessionOptionsService({
  required final AntigravityProtocolMapper _protocolMapper,
  required final AntigravityCatalogTracker _catalogTracker,
  required final AcpSessionConfigRepository _configRepository,
}) {
  /// Called only with real new/load/resume or configuration responses, never a scratch session.
  void capture({required AcpNewSessionResult result, required AntigravityCatalogSource source}) {
    final catalog = _validatedCatalog(result: result);
    if (catalog != null) _store(catalog: catalog, source: source);
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
                  models: [
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

  /// Await before dispatching a prompt. A null model preserves the account/session default.
  Future<void> applyForPrompt({required String sessionId, required String? modelId}) async {
    if (modelId != null) {
      final catalog = _catalogTracker.snapshot;
      if (catalog == null || !catalog.models.any((model) => model.id == modelId)) {
        final diagnosticId = modelId.length <= 120 ? modelId : "${modelId.substring(0, 120)}…";
        throw PluginStaleOptionsException(
          "session/prompt",
          message: "Antigravity model '$diagnosticId' is not in the current account catalog",
        );
      }
      final result = await _configRepository.setConfigOption(
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
    }
    await _configRepository.setMode(sessionId: sessionId, modeId: AntigravitySessionMode.defaultMode.id);
  }
}
