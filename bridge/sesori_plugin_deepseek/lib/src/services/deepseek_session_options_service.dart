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

  Future<PluginSessionOptionsDiscoveryResult> getSessionOptions({
    required AcpStdioClient client,
    required String cwd,
  }) async {
    try {
      return PluginSessionOptionsDiscoveryResult.observed(
        options: await _discover(client: client, cwd: cwd),
      );
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
          "session/set_config_option",
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
    final selection = repository.mapSessionSelection(result);
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

  Future<PluginSessionOptions> _discover({required AcpStdioClient client, required String cwd}) async {
    final options = await repository.discover(client: client, cwd: cwd, timeout: discoveryTimeout);
    if (options.providers.providers.isEmpty) {
      throw const PluginOperationException(
        "deepseek/catalog",
        message: "DeepSeek reported no usable providers",
      );
    }
    final selected = options.agents.single.model;
    configurationTracker.setProcessDefaults(
      modelId: selected?.modelID,
      providerId: selected?.providerID,
    );
    return options;
  }
}
