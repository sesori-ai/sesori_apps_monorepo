import "dart:async";

import "package:acp_plugin/acp_plugin.dart";
import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart" show normalizeProjectDirectory;
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "../foundation/antigravity_identity.dart";
import "../models/antigravity_model_catalog.dart";
import "../repositories/antigravity_catalog_repository.dart";
import "../repositories/mappers/antigravity_protocol_mapper.dart";
import "../trackers/antigravity_catalog_tracker.dart";

class AntigravitySessionOptionsService({
  required final AntigravityProtocolMapper _protocolMapper,
  required final AntigravityCatalogTracker _catalogTracker,
  required final AcpSessionConfigurationTracker _configurationTracker,
  required String discoveryDirectory,
}) {
  Future<PluginSessionOptionsDiscoveryResult>? _discovery;
  String? _reservedSessionId;
  int _connectionGeneration = 0;

  final String _discoveryDirectory = normalizeProjectDirectory(directory: discoveryDirectory);

  Future<PluginSessionOptionsDiscoveryResult> discover({
    required PluginSessionOptionsDiscoveryMode discoveryMode,
    required Future<AntigravityCatalogRepository> Function() repositoryProvider,
  }) {
    if (discoveryMode == PluginSessionOptionsDiscoveryMode.reuse && _catalogTracker.snapshot != null) {
      return Future.value(PluginSessionOptionsDiscoveryResult.observed(options: getSessionOptions()));
    }
    final active = _discovery;
    if (active != null) return active;

    final generation = _connectionGeneration;
    late final Future<PluginSessionOptionsDiscoveryResult> operation;
    operation = _runDiscovery(repositoryProvider: repositoryProvider, generation: generation).whenComplete(() {
      if (identical(_discovery, operation)) _discovery = null;
    });
    _discovery = operation;
    return operation;
  }

  Future<PluginSessionOptionsDiscoveryResult> _runDiscovery({
    required Future<AntigravityCatalogRepository> Function() repositoryProvider,
    required int generation,
  }) async {
    try {
      final repository = await repositoryProvider();
      if (generation != _connectionGeneration) return const PluginSessionOptionsDiscoveryResult.failed();

      var sessionId = _reservedSessionId;
      var source = AntigravityCatalogSource.existingSession;
      final AntigravityCatalogSession result;
      if (sessionId == null) {
        final listed = await repository.listSessions(directory: _discoveryDirectory);
        if (generation != _connectionGeneration) return const PluginSessionOptionsDiscoveryResult.failed();
        final matches = [
          for (final session in listed)
            if (session.sessionId.isNotEmpty && _hasDiscoveryDirectory(session: session)) session.sessionId,
        ]..sort();
        if (matches.isEmpty) {
          result = await repository.createSession(directory: _discoveryDirectory);
          sessionId = result.sessionId;
          source = AntigravityCatalogSource.newSession;
        } else {
          sessionId = matches.first;
          _reservedSessionId = sessionId;
          result = await repository.resumeSession(sessionId: sessionId, directory: _discoveryDirectory);
        }
      } else {
        result = await repository.resumeSession(sessionId: sessionId, directory: _discoveryDirectory);
      }
      if (generation != _connectionGeneration) return const PluginSessionOptionsDiscoveryResult.failed();
      _reservedSessionId = sessionId;
      final catalog = _validateCatalog(catalog: result.catalog);
      _store(catalog: catalog, source: source);
      if (source == AntigravityCatalogSource.newSession) _setProcessSelection(selection: catalog.currentSelection);
      return PluginSessionOptionsDiscoveryResult.observed(options: getSessionOptions());
    } on Object catch (error, stackTrace) {
      Log.w("[antigravity] model catalog discovery failed", error, stackTrace);
      return const PluginSessionOptionsDiscoveryResult.failed();
    }
  }

  bool _hasDiscoveryDirectory({required AcpSessionInfo session}) {
    final directory = session.cwd;
    return directory != null &&
        directory.trim().isNotEmpty &&
        normalizeProjectDirectory(directory: directory) == _discoveryDirectory;
  }

  bool isDiscoverySession({required String sessionId, required String directory}) {
    if (sessionId == _reservedSessionId) return true;
    if (directory.trim().isEmpty) return false;
    return normalizeProjectDirectory(directory: directory) == _discoveryDirectory;
  }

  /// Called only with real new/load/resume or configuration responses.
  void capture({
    required AcpNewSessionResult result,
    required String sessionId,
    required AntigravityCatalogSource source,
  }) {
    final catalog = _validatedCatalog(result: result);
    if (catalog == null) return;
    _store(catalog: catalog, source: source);
    if (source == AntigravityCatalogSource.newSession) _setProcessSelection(selection: catalog.currentSelection);
    _setSessionSelection(sessionId: sessionId, selection: catalog.currentSelection);
  }

  AntigravityModelCatalog? _validatedCatalog({required AcpNewSessionResult result}) {
    final catalog = _protocolMapper.mapModelCatalog(result: result);
    return catalog == null ? null : _validateCatalog(catalog: catalog);
  }

  AntigravityModelCatalog _validateCatalog({required AntigravityModelCatalog catalog}) {
    final ids = <String>{};
    for (final model in catalog.models) {
      if (model.id.trim().isEmpty || model.name.trim().isEmpty || !ids.add(model.id)) {
        throw const FormatException("Antigravity model catalog has empty labels/IDs or duplicate IDs");
      }
      for (final variant in model.variants) {
        if (variant.nativeModelId.trim().isEmpty) {
          throw const FormatException("Antigravity model catalog has an empty native variant ID");
        }
      }
    }
    if (ids.isEmpty || catalog.currentNativeModelId.trim().isEmpty) {
      throw const FormatException("Antigravity model catalog has no selectable current model");
    }
    return catalog;
  }

  void _store({required AntigravityModelCatalog catalog, required AntigravityCatalogSource source}) {
    final previousDefault = _catalogTracker.newSessionDefault;
    final defaultSelection = source == AntigravityCatalogSource.newSession
        ? catalog.currentSelection
        : previousDefault == null
        ? null
        : _resolveSelection(catalog: catalog, modelId: previousDefault.modelId, variantId: previousDefault.variantId);
    _catalogTracker.storeValidated(catalog: catalog, newSessionDefault: defaultSelection);
  }

  void _setProcessSelection({required AntigravityModelSelection selection}) {
    _configurationTracker.setProcessSelection(
      modelId: selection.modelId,
      providerId: AntigravityIdentity.pluginId,
      variantId: selection.variantId,
    );
  }

  void _setSessionSelection({required String sessionId, required AntigravityModelSelection selection}) {
    _configurationTracker.setSessionSelection(
      sessionId: sessionId,
      modelId: selection.modelId,
      providerId: AntigravityIdentity.pluginId,
      variantId: selection.variantId,
    );
  }

  void resetConnection() {
    _connectionGeneration++;
    _discovery = null;
    _catalogTracker.clear();
    _configurationTracker.clear();
  }

  PluginSessionOptions getSessionOptions() {
    final catalog = _catalogTracker.snapshot;
    final defaultSelection = _catalogTracker.newSessionDefault;
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
                          variants: CatalogStrengthOrder.variants(model.variants.map((variant) => variant.kind.id)),
                          defaultVariant: model.variants.isEmpty
                              ? null
                              : model.id == defaultSelection?.modelId
                              ? defaultSelection?.variantId
                              : model.variants.first.kind.id,
                          family: null,
                          isAvailable: true,
                          releaseDate: null,
                        ),
                    ],
                    idOf: (model) => model.id,
                  ),
                  defaultModelID: defaultSelection?.modelId,
                ),
              ],
      ),
      commands: const [],
      completeness: catalog == null
          ? PluginSessionOptionsCompleteness.partial
          : PluginSessionOptionsCompleteness.complete,
    );
  }

  AntigravityModelSelection? _resolveSelection({
    required AntigravityModelCatalog catalog,
    required String modelId,
    required String? variantId,
  }) {
    final model = catalog.models.where((candidate) => candidate.id == modelId).firstOrNull;
    if (model == null) return null;
    if (model is AntigravityStandaloneModel) {
      return variantId == null
          ? AntigravityModelSelection(modelId: model.id, variantId: null, nativeModelId: model.id)
          : null;
    }
    final defaultSelection = _catalogTracker.newSessionDefault;
    final resolvedVariantId =
        variantId ??
        (defaultSelection?.modelId == modelId ? defaultSelection?.variantId : null) ??
        model.variants.first.kind.id;
    final selected = model.variants.where((candidate) => candidate.kind.id == resolvedVariantId).firstOrNull;
    return selected == null
        ? null
        : AntigravityModelSelection(
            modelId: model.id,
            variantId: selected.kind.id,
            nativeModelId: selected.nativeModelId,
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
        (agent != null && agent != AntigravityIdentity.pluginId)) {
      throw PluginStaleOptionsException(
        operation,
        message: "Antigravity supports its primary agent and advertised provider only",
      );
    }
    final catalog = _catalogTracker.snapshot;
    if (modelId != null &&
        catalog != null &&
        _resolveSelection(catalog: catalog, modelId: modelId, variantId: variant?.id) == null) {
      _throwStaleSelection(operation: operation, selectionId: modelId);
    }
    if (modelId == null && variant != null) {
      final offered = catalog?.models.any(
        (model) => model.variants.any((candidate) => candidate.kind.id == variant.id),
      );
      if (offered != true) _throwStaleSelection(operation: operation, selectionId: variant.id);
    }
  }

  /// Await before dispatching a prompt. Null model and variant preserve the session default.
  Future<void> applyForPrompt({
    required AcpSessionConfigRepository configRepository,
    required String sessionId,
    required String? modelId,
    required PluginSessionVariant? variant,
  }) async {
    if (modelId != null || variant != null) {
      final catalog = _catalogTracker.snapshot;
      final resolvedModelId = modelId ?? _configurationTracker.snapshotForSession(sessionId: sessionId).modelId;
      if (catalog == null || resolvedModelId == null) {
        _throwStaleSelection(operation: "session/prompt", selectionId: modelId ?? variant?.id);
      }
      final selection = _resolveSelection(catalog: catalog, modelId: resolvedModelId, variantId: variant?.id);
      if (selection == null) {
        _throwStaleSelection(operation: "session/prompt", selectionId: modelId ?? variant?.id);
      }
      final result = await configRepository.setConfigOption(
        sessionId: sessionId,
        configId: catalog.configId,
        value: selection.nativeModelId,
      );
      if (result != null) {
        final updated = _validatedCatalog(result: result);
        if (updated != null) {
          if (updated.currentNativeModelId != selection.nativeModelId) {
            throw StateError("Antigravity did not apply the requested model selection");
          }
          _store(catalog: updated, source: AntigravityCatalogSource.existingSession);
        }
      }
      _setSessionSelection(sessionId: sessionId, selection: selection);
    }
    await configRepository.setMode(sessionId: sessionId, modeId: AntigravitySessionMode.defaultMode.id);
  }

  Never _throwStaleSelection({required String operation, required String? selectionId}) {
    final raw = selectionId ?? "unresolved";
    final diagnosticId = raw.length <= 120 ? raw : "${raw.substring(0, 120)}…";
    throw PluginStaleOptionsException(
      operation,
      message: "Antigravity selection '$diagnosticId' is not in the current account catalog",
    );
  }
}
