import "package:acp_plugin/acp_plugin.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "../repositories/deepseek_catalog_repository.dart";

class DeepSeekSessionOptionsService({
  required final DeepSeekCatalogRepository repository,
  required final AcpSessionConfigurationTracker configurationTracker,
  required final String pluginId,
  required final Duration discoveryTimeout,
}) {
  static const String modelConfigId = "deepseek.model";
  static const String reasoningConfigId = "deepseek.reasoning_effort";
  static const String _noModelsActionHint =
      "DeepSeek reported no models. Complete DeepSeek provider setup, such as an API key, then retry.";

  /// The providers each project's last catalog discovery reported, for the
  /// send-time check in [validateTurnSelection].
  final Map<String, List<PluginProvider>> _providersByCwd = {};

  /// The model ids DeepSeek offered each session in session/new or
  /// session/load, for a session whose directory has no catalog, such as a
  /// dedicated worktree.
  final Map<String, Set<String>> _sessionModelIds = {};

  Future<PluginSessionOptionsDiscoveryResult> getSessionOptions({
    required AcpStdioClient client,
    required String cwd,
  }) async {
    try {
      final options = await _tryDiscover(client: client, cwd: cwd);
      if (options == null) {
        return const PluginSessionOptionsDiscoveryResult.authenticationRequired(actionHint: _noModelsActionHint);
      }
      return PluginSessionOptionsDiscoveryResult.observed(options: options);
    } on Object catch (error, stackTrace) {
      Log.w("[$pluginId] session option discovery failed", error, stackTrace);
      return const PluginSessionOptionsDiscoveryResult.failed();
    }
  }

  Future<List<PluginAgent>> listAgents({required AcpStdioClient client, required String cwd}) async =>
      (await _discover(client: client, cwd: cwd)).agents;

  Future<PluginProvidersResult> listProviders({required AcpStdioClient client, required String cwd}) async =>
      (await _discover(client: client, cwd: cwd)).providers;

  Future<List<PluginCommand>> listCommands({required AcpStdioClient client, required String cwd}) async =>
      (await _discover(client: client, cwd: cwd)).commands;

  Future<void> applyTurnSelection({
    required AcpSessionConfigRepository configRepository,
    required String sessionId,
    required ({String providerID, String modelID})? model,
    required PluginSessionVariant? variant,
  }) async {
    try {
      if (model != null) {
        await configRepository.setConfigOption(
          sessionId: sessionId,
          configId: modelConfigId,
          value: model.modelID,
        );
      }
      if (variant != null) {
        await configRepository.setConfigOption(
          sessionId: sessionId,
          configId: reasoningConfigId,
          value: variant.id,
        );
      }
    } on Object catch (error, stackTrace) {
      Error.throwWithStackTrace(
        PluginOperationException(
          operation: "session/set_config_option",
          message: "DeepSeek rejected the requested session selection",
          cause: error,
        ),
        stackTrace,
      );
    }
    if (model != null) {
      configurationTracker.setSessionOverride(
        sessionId: sessionId,
        modelId: model.modelID,
        providerId: model.providerID,
      );
    }
  }

  void captureSessionConfig(
    AcpNewSessionResult result, {
    required String? sessionId,
    required bool fromNewSession,
  }) {
    final modelIds = repository.mapSessionModelIds(result: result);
    if (sessionId != null && modelIds != null && modelIds.isNotEmpty) _sessionModelIds[sessionId] = modelIds;
    final selection = repository.mapSessionSelection(result: result);
    if (selection == null) return;
    if (fromNewSession) {
      configurationTracker.setProcessDefaults(
        modelId: selection.modelId,
        providerId: selection.providerId,
      );
    }
    if (sessionId != null) {
      configurationTracker.setSessionOverride(
        sessionId: sessionId,
        modelId: selection.modelId,
        providerId: selection.providerId,
      );
    }
  }

  /// Refuses a [model] or [variant] missing from the catalog DeepSeek last
  /// reported for [cwd]. Without one, only [model] is checked, against the
  /// models DeepSeek offered the session itself. With neither, nothing is.
  void validateTurnSelection({
    required String operation,
    required String sessionId,
    required String cwd,
    required ({String providerID, String modelID})? model,
    required PluginSessionVariant? variant,
  }) {
    final providers = _providersByCwd[cwd];
    if (providers == null) {
      final offered = _sessionModelIds[sessionId];
      if (model != null && offered != null && !offered.contains(model.modelID)) {
        throw PluginStaleOptionsException(
          operation: operation,
          message: "DeepSeek no longer offers the selected model",
        );
      }
      return;
    }
    final current = configurationTracker.snapshotForSession(sessionId: sessionId);
    final modelId = model?.modelID ?? current.modelId;
    final providerId = model?.providerID ?? current.providerId;
    if (modelId == null) return;
    final listed = providers
        .where((provider) => providerId == null || provider.id == providerId)
        .expand((provider) => provider.models)
        .where((entry) => entry.id == modelId)
        .firstOrNull;
    if (listed == null) {
      if (model == null) return;
      throw PluginStaleOptionsException(operation: operation, message: "DeepSeek no longer offers the selected model");
    }
    if (variant != null && !listed.variants.contains(variant.id)) {
      throw PluginStaleOptionsException(
        operation: operation,
        message: "DeepSeek no longer offers the selected reasoning level",
      );
    }
  }

  Future<PluginSessionOptions> _discover({required AcpStdioClient client, required String cwd}) async =>
      await _tryDiscover(client: client, cwd: cwd) ??
      (throw const PluginOperationException(operation: "deepseek/catalog", message: _noModelsActionHint));

  /// Returns null when DeepSeek lists no models, which it does until a provider credential is configured.
  Future<PluginSessionOptions?> _tryDiscover({required AcpStdioClient client, required String cwd}) async {
    final options = await repository.discover(client: client, cwd: cwd, timeout: discoveryTimeout);
    if (options.providers.providers.isEmpty) {
      _providersByCwd.remove(cwd);
      return null;
    }
    _providersByCwd[cwd] = options.providers.providers;
    final selected = options.agents.single.model;
    configurationTracker.setProcessDefaults(
      modelId: selected?.modelID,
      providerId: selected?.providerID,
    );
    return options;
  }
}
